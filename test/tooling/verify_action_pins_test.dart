// `dart run tool/check_action_pins.dart --verify-tags` checks each pinned SHA
// against the commit its `# vX.Y.Z` tag names. The Action pins workflow runs
// it against the GitHub API; these tests run it offline: `verifyTags` with a
// table for a resolver, and `ghTagResolver` against a fake `gh` that answers
// from a table, so the comparison, the YAML reading, the annotated-tag peeling
// and the error paths are pinned without a network.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_action_pins.dart';

const _tagSha = '1111111111111111111111111111111111111111';
const _commit = '2222222222222222222222222222222222222222';
const _forkCommit = '3333333333333333333333333333333333333333';

/// A scratch repository whose only workflow is [workflow].
Directory _repo(String workflow) {
  final root = Directory.systemTemp.createTempSync('verify_pins_');
  addTearDown(() => root.deleteSync(recursive: true));
  File('${root.path}/.github/workflows/w.yml')
    ..createSync(recursive: true)
    ..writeAsStringSync(workflow);
  return root;
}

/// `verifyTags` over [workflow], with `a/b`'s `v1.0.0` naming [_commit].
List<String> _problems(String workflow) => verifyTags(
  _repo(workflow),
  (repo, tag) => repo == 'a/b' && tag == 'v1.0.0' ? _commit : null,
).problems.map((p) => p.split('/.github/workflows/').last).toList();

/// A fake `gh` answering `gh api <path>` from [api] (`path -> "type sha"`);
/// it fails like a 500 on a path ending in `/fail`, like a 404 on any other.
String _fakeGh(Map<String, String> api) {
  final bin = Directory.systemTemp.createTempSync('fake_gh_');
  addTearDown(() => bin.deleteSync(recursive: true));
  final gh = File('${bin.path}/gh')
    ..writeAsStringSync('''
#!/usr/bin/env bash
case "\$2" in
${[for (final MapEntry(:key, :value) in api.entries) '  "$key") echo "$value" ;;'].join('\n')}
  */fail) echo "gh: Server Error (HTTP 500)" >&2; exit 1 ;;
  *) echo "gh: Not Found (HTTP 404)" >&2; exit 1 ;;
esac
''');
  Process.runSync('chmod', ['+x', gh.path]);
  return gh.path;
}

void main() {
  group('verifyTags', () {
    test('accepts a pin that is its tag commit', () {
      final root = _repo('steps:\n  - uses: a/b@$_commit # v1.0.0\n');
      final result = verifyTags(root, (_, _) => _commit);
      expect(result.problems, isEmpty);
      expect(result.verified, 1);
    });

    test('rejects a SHA that is not the tag commit, naming both', () {
      expect(_problems('steps:\n  - uses: a/b/sub@$_forkCommit # v1.0.0\n'), [
        'w.yml:2: a/b v1.0.0 is $_commit, but the pin is $_forkCommit',
      ]);
    });

    test('rejects a version comment that is not a tag', () {
      expect(_problems('steps:\n  - uses: a/b@$_commit # v9.9.9\n'), [
        'w.yml:2: a/b has no tag v9.9.9; the pin is $_commit',
      ]);
    });

    test('checks the uses value, not a pin written in another key', () {
      expect(
        _problems(
          'steps:\n'
          '  - {name: "a/b@$_commit # v1.0.0 ", uses: a/b@$_forkCommit} '
          '# v1.0.0\n',
        ),
        ['w.yml:2: a/b v1.0.0 is $_commit, but the pin is $_forkCommit'],
      );
    });

    test('checks every step on a line, not only the first', () {
      expect(
        _problems(
          'steps: [{uses: a/b@$_commit}, {uses: a/b@$_forkCommit}] # v1.0.0\n',
        ),
        [
          'w.yml:1: uses: a/b@$_commit is not a pinned release',
          'w.yml:1: a/b v1.0.0 is $_commit, but the pin is $_forkCommit',
        ],
      );
    });

    test('reads pins written with YAML escapes', () {
      final fork = _forkCommit.substring(1);
      expect(
        _problems(
          'steps:\n'
          '  - uses: "a/b@\\x33$fork" # v1.0.0\n'
          '  - uses: "a/b@${_forkCommit.substring(0, 20)}\\\n'
          '      ${_forkCommit.substring(20)}" # v1.0.0\n',
        ),
        [
          'w.yml:2: a/b v1.0.0 is $_commit, but the pin is $_forkCommit',
          'w.yml:3: a/b v1.0.0 is $_commit, but the pin is $_forkCommit',
        ],
      );
    });

    test('resolves each repo@tag once', () {
      var calls = 0;
      final root = _repo(
        'steps:\n'
        '  - uses: a/b@$_commit # v1.0.0\n'
        '  - uses: a/b/sub@$_commit # v1.0.0\n',
      );
      final result = verifyTags(root, (_, _) {
        calls++;
        return _commit;
      });
      expect(result.verified, 2);
      expect(calls, 1);
    });
    test('never asks the API about a comment that is not a release tag', () {
      final root = _repo(
        'steps:\n'
        '  - uses: a/b@$_commit # v1.0.0/../../../../x/y/git/ref/tags/v2\n'
        '  - uses: a/b@$_commit # v1.0.0?x\n',
      );
      final result = verifyTags(
        root,
        (repo, tag) => fail('resolver called with $repo $tag'),
      );
      expect(result.problems, hasLength(2));
      expect(result.verified, 0);
    });
  });

  group('ghTagResolver', () {
    test('returns a lightweight tag commit', () {
      final resolve = ghTagResolver(
        gh: _fakeGh({'repos/a/b/git/ref/tags/v1.0.0': 'commit $_commit'}),
      );
      expect(resolve('a/b', 'v1.0.0'), _commit);
    });

    test('peels an annotated tag to its commit', () {
      final resolve = ghTagResolver(
        gh: _fakeGh({
          'repos/a/b/git/ref/tags/v1.0.0': 'tag $_tagSha',
          'repos/a/b/git/tags/$_tagSha': 'commit $_commit',
        }),
      );
      expect(resolve('a/b', 'v1.0.0'), _commit);
    });

    test('returns null for a missing tag', () {
      expect(ghTagResolver(gh: _fakeGh({}))('a/b', 'v9.9.9'), isNull);
    });

    test('throws, rather than passing, when the API cannot be asked', () {
      final resolve = ghTagResolver(
        gh: _fakeGh({'repos/a/b/git/ref/tags/v1.0.0': 'tag fail'}),
      );
      expect(
        () => resolve('a/b', 'v1.0.0'),
        throwsA(
          isA<TagLookupException>().having(
            (e) => e.message,
            'message',
            contains('HTTP 500'),
          ),
        ),
      );
    });
  });
}
