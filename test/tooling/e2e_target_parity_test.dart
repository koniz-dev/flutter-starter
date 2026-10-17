// The local E2E script and the CI E2E workflow must run the same Patrol
// target (koniz-dev/flutter-starter#578, split from #378).
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
}
