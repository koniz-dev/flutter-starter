// ci.yml must fail when committed generated code drifts from its sources.
//
// Five .g.dart files had gone stale with nothing noticing: a provider was
// edited without re-running build_runner, and the next adopter to regenerate
// got an unrelated diff. The Quality gate now regenerates and fails on any
// change; this pins that step, and that it runs before the analyze step.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final ci = File('.github/workflows/ci.yml').readAsStringSync();

  test('criterion 2: the Quality gate regenerates and fails on drift', () {
    expect(ci, contains('- name: Check generated code is up to date'));
    expect(ci, contains('dart run build_runner build -d'));
    expect(
      ci,
      contains("git status --porcelain -- '*.g.dart' '*.freezed.dart'"),
    );
    expect(ci, contains('exit 1'));
  });

  test('it runs after pub get and before analyze', () {
    final install = ci.indexOf('- name: Install dependencies');
    final check = ci.indexOf('- name: Check generated code is up to date');
    final analyze = ci.indexOf('- name: Analyze code');

    expect(install, isNonNegative);
    expect(check, greaterThan(install));
    expect(analyze, greaterThan(check));
  });
}
