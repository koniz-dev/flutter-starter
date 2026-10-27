// Every action a workflow runs is pinned to a full commit SHA. A tag such as
// `@v2` can be moved to another commit by whoever controls the action's
// repository, and the deploy workflows hand that commit the project's store,
// hosting and signing secrets. A SHA cannot move. The `# vX.Y.Z` comment after
// it is what Dependabot's github-actions updates read and rewrite.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `uses: owner/repo[/path]@<40 hex> # v1.2.3`
final _pinned = RegExp(
  r'^uses:\s+[\w.-]+/[\w./-]+@[0-9a-f]{40}\s+#\s+v?\d+(\.\d+){1,2}\S*\s*$',
);

/// Exempt: actions in this repository, and container images by digest.
bool _exempt(String target) =>
    target.startsWith('./') ||
    (target.startsWith('docker://') && target.contains('@sha256:'));

/// Each `uses:` line in [workflow] that is not pinned, as `file:line: text`.
List<String> unpinnedUses(String path, String workflow) {
  final found = <String>[];
  final lines = workflow.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim().replaceFirst(RegExp(r'^-\s+'), '');
    if (!line.startsWith('uses:')) continue;
    final target = line.substring('uses:'.length).trim().split(RegExp(r'\s'));
    if (_exempt(target.first)) continue;
    if (!_pinned.hasMatch(line)) found.add('$path:${i + 1}: $line');
  }
  return found;
}

void main() {
  test('every workflow action is pinned to a commit SHA with its version', () {
    final workflows =
        Directory('.github/workflows')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.yml') || f.path.endsWith('.yaml'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    expect(workflows, isNotEmpty);

    final unpinned = [
      for (final f in workflows) ...unpinnedUses(f.path, f.readAsStringSync()),
    ];
    expect(
      unpinned,
      isEmpty,
      reason:
          'Pin each action to the commit of a release, with the release as '
          'a comment: uses: owner/repo@<40-hex sha> # vX.Y.Z',
    );
  });

  group('the pin check itself', () {
    const sha = '3d3c42e5aac5ba805825da76410c181273ba90b1';

    test('accepts a SHA with its version comment', () {
      expect(
        unpinnedUses('w.yml', '      - uses: actions/checkout@$sha # v7.0.1'),
        isEmpty,
      );
    });

    test('rejects a tag, a branch, a short SHA and a missing comment', () {
      for (final ref in [
        'actions/checkout@v7',
        'actions/checkout@main',
        'actions/checkout@3d3c42e',
        'actions/checkout@$sha',
      ]) {
        expect(
          unpinnedUses('w.yml', 'steps:\n  - uses: $ref'),
          ['w.yml:2: uses: $ref'],
          reason: ref,
        );
      }
    });

    test('exempts local actions and docker images by digest', () {
      expect(
        unpinnedUses(
          'w.yml',
          '- uses: ./.github/actions/setup\n'
              '- uses: docker://alpine@sha256:${'a' * 64}',
        ),
        isEmpty,
      );
    });
  });
}
