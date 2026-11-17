// Workflow hardening.
//
// The three deploy workflows declared no `permissions:` - so they ran with the
// default token scope - and no `concurrency:`, so two deploys could race; and
// every workflow used Node 20 action majors that GitHub has deprecated.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Action majors that still run on Node 20, and the Node 24 major each moved
/// to. Dependabot (`.github/dependabot.yml`) now proposes newer majors; this
/// list keeps the deprecated ones from coming back.
const _node20Majors = {
  'actions/checkout@v4': 'actions/checkout@v7',
  'actions/setup-java@v4': 'actions/setup-java@v6',
  'actions/upload-artifact@v4': 'actions/upload-artifact@v7',
  'codecov/codecov-action@v4': 'codecov/codecov-action@v7',
  'marocchino/sticky-pull-request-comment@v2':
      'marocchino/sticky-pull-request-comment@v3',
};

void main() {
  final workflows =
      Directory('.github/workflows')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.yml'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('the scan sees the workflows', () {
    // Not an exact count: the strip variants remove workflows of their own.
    expect(workflows, isNotEmpty);
    expect(workflows.map((f) => f.uri.pathSegments.last), contains('ci.yml'));
  });

  for (final workflow in workflows) {
    final name = workflow.uri.pathSegments.last;
    final text = workflow.readAsStringSync();

    test('criterion 1: $name declares top-level permissions', () {
      expect(text, contains(RegExp('^permissions:', multiLine: true)));
      expect(
        text,
        isNot(contains(RegExp(r'^permissions:\s*write-all', multiLine: true))),
      );
    });

    test('criterion 3: $name uses no Node 20 action major', () {
      final stale = [
        for (final ref in _node20Majors.keys)
          if (text.contains('$ref\n') || text.contains('$ref ')) ref,
      ];
      expect(
        stale,
        isEmpty,
        reason: 'bump to ${[for (final r in stale) _node20Majors[r]]}',
      );
    });
  }

  for (final name in const [
    'deploy-android.yml',
    'deploy-ios.yml',
    'deploy-web.yml',
  ]) {
    test('criteria 1-2: $name reads only, and never races or cancels a '
        'deploy', () {
      final text = File('.github/workflows/$name').readAsStringSync();
      expect(
        text,
        contains(RegExp(r'^permissions:\n  contents: read\n', multiLine: true)),
      );
      expect(text, contains(RegExp('^concurrency:', multiLine: true)));
      expect(text, contains('cancel-in-progress: false'));
    });
  }

  // `cancel-in-progress: true` keyed on the ref also cancelled pushes to
  // main, so commits merged close together never got a full run there (7 of
  // 40 main runs were cancelled).
  test('no workflow that runs on push cancels an in-progress push run', () {
    for (final file in Directory('.github/workflows').listSync()) {
      if (file is! File || !file.path.endsWith('.yml')) continue;
      final text = file.readAsStringSync();
      final on = RegExp(
        r'^on:\n((?:[ #].*\n|\n)*)',
        multiLine: true,
      ).firstMatch(text)?.group(1);
      if (on == null || !RegExp('^  push:', multiLine: true).hasMatch(on)) {
        continue;
      }
      expect(
        text,
        isNot(contains('cancel-in-progress: true')),
        reason: '${file.path} runs on push; cancel only pull_request runs',
      );
    }
  });
}
