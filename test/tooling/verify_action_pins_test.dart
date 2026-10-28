// `scripts/ci/verify_action_pins.sh` checks each pinned SHA against the commit
// its `# vX.Y.Z` tag names, through the GitHub API. The Action pins workflow
// runs it for real; these tests run it offline against a fake `gh` on PATH
// that answers from a table, so the comparison, the annotated-tag peeling and
// the error paths are pinned without a network.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final String _script = File('scripts/ci/verify_action_pins.sh').absolute.path;

const _tagSha = '1111111111111111111111111111111111111111';
const _commit = '2222222222222222222222222222222222222222';
const _forkCommit = '3333333333333333333333333333333333333333';

/// Runs the script in a scratch repository holding [workflow], with a fake
/// `gh` that answers `gh api <path>` from [api] (`path -> "type sha"`), fails
/// like a 500 on a path ending in `/fail`, and like a 404 on any other.
ProcessResult _verify(String workflow, Map<String, String> api) {
  final root = Directory.systemTemp.createTempSync('verify_pins_');
  addTearDown(() => root.deleteSync(recursive: true));
  File('${root.path}/.github/workflows/w.yml')
    ..createSync(recursive: true)
    ..writeAsStringSync(workflow);
  final bin = Directory('${root.path}/bin')..createSync();
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
  return Process.runSync(
    'bash',
    [_script],
    workingDirectory: root.path,
    environment: {'PATH': '${bin.path}:${Platform.environment['PATH']}'},
  );
}

String _out(ProcessResult r) => '${r.stdout}${r.stderr}';

void main() {
  test('accepts a pin that is its lightweight tag', () {
    final r = _verify('steps:\n  - uses: a/b@$_commit # v1.0.0\n', {
      'repos/a/b/git/ref/tags/v1.0.0': 'commit $_commit',
    });
    expect(r.exitCode, 0, reason: _out(r));
    expect(r.stdout, contains('1 pins in 1 files match'));
  });

  test('peels an annotated tag to its commit', () {
    final r = _verify('steps:\n  - uses: a/b@$_commit # v1.0.0\n', {
      'repos/a/b/git/ref/tags/v1.0.0': 'tag $_tagSha',
      'repos/a/b/git/tags/$_tagSha': 'commit $_commit',
    });
    expect(r.exitCode, 0, reason: _out(r));
  });

  test('rejects a SHA that is not the tag commit, naming both', () {
    final r = _verify(
      'steps:\n'
      '  - uses: a/b@$_commit # v1.0.0\n'
      '  - {name: x, uses: a/b/sub@$_forkCommit} # v1.0.0\n',
      {'repos/a/b/git/ref/tags/v1.0.0': 'commit $_commit'},
    );
    expect(r.exitCode, 1, reason: _out(r));
    expect(
      r.stderr,
      contains(
        '.github/workflows/w.yml:3: a/b v1.0.0 is $_commit, '
        'but the pin is $_forkCommit',
      ),
    );
    expect(r.stderr, isNot(contains('w.yml:2')));
  });

  test('rejects a version comment that is not a tag', () {
    final r = _verify('steps:\n  - uses: a/b@$_commit # v9.9.9\n', {});
    expect(r.exitCode, 1, reason: _out(r));
    expect(r.stderr, contains('w.yml:2: a/b has no tag v9.9.9'));
  });

  test('exits 2 when the API cannot be asked, rather than passing', () {
    final r = _verify('steps:\n  - uses: a/b@$_commit # v1.0.0\n', {
      'repos/a/b/git/ref/tags/v1.0.0': 'tag fail',
    });
    expect(r.exitCode, 2, reason: _out(r));
    expect(r.stderr, contains('HTTP 500'));
  });
}
