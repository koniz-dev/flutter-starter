// test_coverage.ps1 ran `flutter test --coverage` under
// `$ErrorActionPreference = "Stop"`, which does not stop on a native
// command's exit code, so failing tests still ended in "Tests completed" and
// exit 0. It also skipped tool/coverage_helper.dart, so files no test loads
// were left out of the total. No PowerShell runs here: these read the script.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final script = File('scripts/test/test_coverage.ps1').readAsStringSync();

  /// The script's lines with comments and blank lines removed.
  final lines = [
    for (final line in script.split('\n'))
      if (line.trim().isNotEmpty && !line.trim().startsWith('#')) line.trim(),
  ];

  test('every native command is followed by a LASTEXITCODE check', () {
    for (final command in [
      'dart run tool/coverage_helper.dart',
      'flutter test --coverage',
    ]) {
      final at = lines.indexOf(command);
      expect(at, isNot(-1), reason: '$command is not run');
      expect(
        lines[at + 1],
        r'if ($LASTEXITCODE -ne 0) {',
        reason: 'nothing checks the exit code of $command',
      );
    }
  });

  test('the coverage helper runs before the tests and is removed after', () {
    expect(
      lines.indexOf('dart run tool/coverage_helper.dart'),
      lessThan(lines.indexOf('flutter test --coverage')),
    );
    final cleanup = lines.indexWhere(
      (l) => l.contains('Remove-Item') && l.contains('coverage_helper_test'),
    );
    expect(cleanup, isNot(-1));
    expect(lines.sublist(0, cleanup), contains('} finally {'));
  });
}
