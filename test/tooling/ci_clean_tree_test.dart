// The Quality gate fails when its own pub get, analyze or test leave a tracked
// file modified (koniz-dev/flutter-starter#608, split from #338). The
// migrations Flutter applies on a fresh pub get are committed, so a diff
// there means a new stable changed something, and the job says what to do.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final ci = File('.github/workflows/ci.yml').readAsStringSync();
  final names = RegExp(
    r'^      - name: (.+)$',
    multiLine: true,
  ).allMatches(ci).map((m) => m.group(1)!).toList();
  final step = RegExp(
    r'- name: Tracked files are unchanged\n(.*?)(?=\n      - name: |\n\S|$)',
    dotAll: true,
  ).firstMatch(ci)?.group(1);

  test('criterion 2: the check exists and runs after the tests', () {
    expect(step, isNotNull);
    expect(
      names.indexOf('Tracked files are unchanged'),
      greaterThan(names.indexOf('Run tests (random order)')),
    );
  });

  test(
    'criterion 2: it fails on a modified tracked file and names the fix',
    () {
      expect(step, contains('git status --porcelain --untracked-files=no'));
      expect(step, contains('exit 1'));
      expect(step, contains('Run flutter pub get on main'));
    },
  );

  test('criterion 1: the committed analyzer excludes match the migration', () {
    final options = File('analysis_options.yaml').readAsStringSync();
    for (final dir in [
      'build',
      'android',
      'ios',
      'web',
      'windows',
      'macos',
      'linux',
    ]) {
      expect(options, contains('    - $dir/**'), reason: dir);
    }
  });
}
