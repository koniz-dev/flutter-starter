// The local E2E script and the CI E2E workflow must run the same Patrol
// target (koniz-dev/flutter-starter#578, split from #378), and that target is
// the only E2E test (koniz-dev/flutter-starter#378).
//
// scripts/test/run_e2e_tests.sh ran integration_test/auth_flow_test.dart
// while e2e-android.yml ran app_e2e_test.dart - a near-identical copy - so a
// fix verified locally could miss the file CI runs.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final RegExp _target = RegExp(
  r'patrol test\s+(?:-t|--target)\s+(integration_test/[\w/]+\.dart)',
);

Set<String> _targets(String path) => {
  for (final m in _target.allMatches(File(path).readAsStringSync()))
    m.group(1)!,
};

void main() {
  test('criterion 1: run_e2e_tests.sh and e2e-android.yml run the same '
      'target', () {
    final local = _targets('scripts/test/run_e2e_tests.sh');
    final ci = _targets('.github/workflows/e2e-android.yml');

    expect(ci, isNotEmpty);
    expect(local, ci);
    for (final target in ci) {
      expect(File(target).existsSync(), isTrue, reason: target);
    }
  });

  test('criterion 1 (#378): the CI target is the only E2E test, in the repo '
      'and in every strip golden', () {
    final ci = _targets('.github/workflows/e2e-android.yml');
    Set<String> e2eTests(String dir) => {
      for (final f in Directory(dir).listSync().whereType<File>())
        if (f.path.endsWith('_test.dart'))
          'integration_test/${f.uri.pathSegments.last}',
    };

    expect(e2eTests('integration_test'), ci);
    for (final golden in Directory('tool/golden').listSync()) {
      final dir = Directory('${golden.path}/integration_test');
      if (!dir.existsSync()) continue;
      expect(e2eTests(dir.path), ci, reason: dir.path);
    }
  });
}
