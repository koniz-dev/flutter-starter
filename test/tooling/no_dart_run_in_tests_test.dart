// `dart run <file>` runs the build-hook step and bundles native assets into
// .dart_tool/ on every call. Several tests spawning it at once raced on those
// files, and dartdev crashed (`Null check operator used on a null value` in
// parseOtoolArchitectureSections), failing the suite at random. Tests run a
// Dart file as `dart --packages=<config> <file>`, which skips that step.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `Process.run('dart', ['run'` or `Process.runSync('dart', ['run'`, however
/// the list is wrapped.
final RegExp _dartRun = RegExp(
  r"""Process\.run(Sync)?\(\s*'dart',\s*(<String>)?\[\s*'run'""",
);

void main() {
  test('no test spawns dart run', () {
    final offenders = <String>[];
    for (final entity in Directory('test').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // This file quotes the pattern in its own documentation.
      if (entity.path.endsWith('no_dart_run_in_tests_test.dart')) continue;
      if (_dartRun.hasMatch(entity.readAsStringSync())) {
        offenders.add(entity.path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: "run the file as 'dart --packages=<config> <file>' instead",
    );
  });
}
