// test_coverage.sh writes test/coverage_helper_test.dart, a git-ignored test
// importing every library under lib/, and never removed it. After the next
// rename or delete under lib/ the leftover imported a library that no longer
// existed, and flutter analyze, flutter test and the pre-push hook failed on a
// file the developer never wrote and git status did not show. It is now
// removed whenever the script exits.

@TestOn('mac-os || linux')
// The stub scripts must start with their shebang, so no leading newline.
// ignore_for_file: leading_newlines_in_multiline_strings
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `dart` stand-in: `dart run tool/coverage_helper.dart` writes the helper.
const _stubDart = '''#!/usr/bin/env bash
mkdir -p test
echo "// generated" > test/coverage_helper_test.dart
''';

/// `flutter` stand-in: writes lcov.info, then exits with $FLUTTER_EXIT.
const _stubFlutter = r'''#!/usr/bin/env bash
mkdir -p coverage
printf 'SF:lib/a.dart\nDA:1,1\nLF:1\nLH:1\nend_of_record\n' > coverage/lcov.info
exit "${FLUTTER_EXIT:-0}"
''';

void main() {
  final repo = Directory.current.path;

  for (final (label, flutterExit) in [('passes', '0'), ('fails', '1')]) {
    test('the helper test is gone after a run whose tests $label', () {
      final dir = Directory.systemTemp.createTempSync('coverage_cleanup_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final bin = Directory('${dir.path}/bin')..createSync();
      for (final (name, body) in [
        ('dart', _stubDart),
        ('flutter', _stubFlutter),
      ]) {
        File('${bin.path}/$name').writeAsStringSync(body);
        Process.runSync('chmod', ['+x', '${bin.path}/$name']);
      }
      final scripts = Directory('${dir.path}/scripts/test')
        ..createSync(recursive: true);
      for (final script in [
        'test_coverage.sh',
        'calculate_layer_coverage.sh',
      ]) {
        File('$repo/scripts/test/$script').copySync('${scripts.path}/$script');
      }

      final result = Process.runSync(
        'bash',
        ['scripts/test/test_coverage.sh', '--min=0'],
        workingDirectory: dir.path,
        environment: {
          'PATH': '${bin.path}:${Platform.environment['PATH']}',
          'FLUTTER_EXIT': flutterExit,
        },
      );

      expect(
        File('${dir.path}/test/coverage_helper_test.dart').existsSync(),
        isFalse,
        reason: 'exit ${result.exitCode}: ${result.stdout}${result.stderr}',
      );
      if (flutterExit != '0') expect(result.exitCode, isNot(0));
    });
  }
}
