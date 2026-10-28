// Every action a workflow or composite action runs is pinned to a full commit
// SHA with its release as a comment; `tool/check_action_pins.dart` says why.
// These tests run it over the real `.github/` files and pin its parsing on
// fixtures, including the YAML spellings a line match would miss.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_action_pins.dart';

List<String> _unpinned(String source, {String path = 'w.yml'}) => [
  for (final use in unpinnedUses(path, source)) '$use',
];

/// A scratch repository holding [files] (`relative path -> content`).
Directory _repo(Map<String, String> files) {
  final root = Directory.systemTemp.createTempSync('action_pins_');
  addTearDown(() => root.deleteSync(recursive: true));
  for (final MapEntry(:key, :value) in files.entries) {
    File('${root.path}/$key')
      ..createSync(recursive: true)
      ..writeAsStringSync(value);
  }
  return root;
}

void main() {
  test('every workflow action is pinned to a commit SHA with its version', () {
    final files = actionFiles(Directory.current);
    expect(
      files.where((f) => f.path.contains('/.github/workflows/')),
      isNotEmpty,
    );

    expect(
      checkActionPins(Directory.current),
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
        _unpinned('      - uses: actions/checkout@$sha # v7.0.1'),
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
          _unpinned('steps:\n  - uses: $ref'),
          ['w.yml:2: uses: $ref'],
          reason: ref,
        );
      }
    });

    test('exempts local actions and docker images by digest', () {
      expect(
        _unpinned(
          '- uses: ./.github/actions/setup\n'
          '- uses: docker://alpine@sha256:${'a' * 64}',
        ),
        isEmpty,
      );
    });

    test('finds uses however the key is spelled', () {
      for (final step in [
        '- {name: x, uses: evil/act@v1}',
        '- "uses": evil/act@v1',
        "- 'uses': evil/act@v1",
        '- uses : evil/act@v1',
      ]) {
        expect(
          _unpinned('steps:\n  $step'),
          ['w.yml:2: uses: evil/act@v1'],
          reason: step,
        );
      }
    });

    test('accepts a pinned flow-mapping step', () {
      expect(
        _unpinned(
          'steps:\n  - {name: x, uses: actions/checkout@$sha} # v7.0.1',
        ),
        isEmpty,
      );
    });

    test('finds a job-level reusable workflow', () {
      expect(
        _unpinned(
          'jobs:\n  call:\n    uses: evil/repo/.github/workflows/x.yml@v1',
        ),
        ['w.yml:3: uses: evil/repo/.github/workflows/x.yml@v1'],
      );
    });

    test('scans composite actions under .github/', () {
      final root = Directory.systemTemp.createTempSync('action_pins_');
      addTearDown(() => root.deleteSync(recursive: true));
      File('${root.path}/.github/workflows/ci.yml')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          'jobs:\n  a:\n    steps:\n      - uses: ./.github/actions/setup\n',
        );
      final action = File('${root.path}/.github/actions/setup/action.yml')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          'runs:\n'
          '  using: composite\n'
          '  steps:\n'
          '    - uses: evil/act@v1\n',
        );

      final files = actionFiles(root);
      expect(files.map((f) => f.path), contains(action.path));
      expect(
        [
          for (final f in files) ...unpinnedUses(f.path, f.readAsStringSync()),
        ].map((u) => '$u'),
        ['${action.path}:4: uses: evil/act@v1'],
      );
    });
    test('follows uses: ./path to a local action outside .github/', () {
      final root = _repo({
        '.github/workflows/ci.yml':
            'jobs:\n  a:\n    steps:\n      - uses: ./tools/setup\n',
        'tools/setup/action.yml':
            'runs:\n  using: composite\n  steps:\n    - uses: evil/act@v1\n',
      });
      expect(checkActionPins(root), [
        '${root.path}/tools/setup/action.yml:4: uses: evil/act@v1',
      ]);
    });

    test('follows local actions that call local actions', () {
      final root = _repo({
        '.github/workflows/ci.yml':
            'jobs:\n  a:\n    steps:\n      - uses: ./a\n',
        'a/action.yaml':
            'runs:\n  using: composite\n  steps:\n    - uses: ./b\n',
        'b/action.yml':
            'runs:\n  using: composite\n  steps:\n    - uses: evil/act@v1\n',
      });
      expect(checkActionPins(root), [
        '${root.path}/b/action.yml:4: uses: evil/act@v1',
      ]);
    });

    test('reports a local action that has no action.yml', () {
      final root = _repo({
        '.github/workflows/ci.yml':
            'jobs:\n  a:\n    steps:\n      - uses: ./tools/gone\n',
      });
      const reason = '(no action.yml or action.yaml there)';
      expect(checkActionPins(root), [
        '${root.path}/.github/workflows/ci.yml:4: uses: ./tools/gone $reason',
      ]);
    });
  });
}
