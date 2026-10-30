// Both coverage threshold checks compare with
// `(( $(echo "$a < $b" | bc -l) ))`. bc prints nothing for a value that is
// not a number, an empty (( )) is false, and the "meets minimum" branch ran:
// `test_coverage.sh --min=abc` exited 0, and so would an empty percentage
// from a changed lcov format.
@TestOn('mac-os || linux')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The `check_threshold` function body from coverage.yml's enforcement step,
/// de-indented so bash can run it on its own.
String _checkThreshold() {
  final yml = File('.github/workflows/coverage.yml').readAsStringSync();
  final body = RegExp(
    r'^( *)check_threshold\(\) \{\n.*?^\1\}',
    multiLine: true,
    dotAll: true,
  ).firstMatch(yml);
  expect(body, isNotNull, reason: 'coverage.yml has no check_threshold');
  final indent = body!.group(1)!.length;
  return body
      .group(0)!
      .split('\n')
      .map((l) => l.length >= indent ? l.substring(indent) : l.trimLeft())
      .join('\n');
}

void main() {
  final repo = Directory.current.path;
  late Directory workdir;

  setUp(() {
    workdir = Directory.systemTemp.createTempSync('coverage_fail_closed');
    Directory('${workdir.path}/coverage').createSync();
    File('${workdir.path}/coverage/lcov.info').writeAsStringSync(
      'SF:lib/a.dart\nDA:1,1\nDA:2,0\nLF:2\nLH:1\nend_of_record\n',
    );
  });

  tearDown(() => workdir.deleteSync(recursive: true));

  group('test_coverage.sh', () {
    ProcessResult run(String script, List<String> args) => Process.runSync(
      'bash',
      [script, '--no-test', ...args],
      workingDirectory: workdir.path,
    );

    test('--min=abc exits non-zero and says why', () {
      final result = run('$repo/scripts/test/test_coverage.sh', [
        '--min=abc',
      ]);

      expect(result.exitCode, isNot(0));
      expect('${result.stdout}', contains('--min must be a number'));
    });

    test('a numeric --min still passes and fails as before', () {
      final script = '$repo/scripts/test/test_coverage.sh';
      expect(run(script, ['--min=50']).exitCode, 0);
      expect(run(script, ['--min=50.5']).exitCode, isNot(0));
    });

    test('a percentage it cannot measure fails the check', () {
      // A copy of the script next to a layer counter that prints nothing,
      // as a changed lcov format would leave it.
      final scripts = Directory('${workdir.path}/scripts')..createSync();
      final script = File('${scripts.path}/test_coverage.sh')
        ..writeAsStringSync(
          File('$repo/scripts/test/test_coverage.sh').readAsStringSync(),
        );
      File(
        '${scripts.path}/calculate_layer_coverage.sh',
      ).writeAsStringSync('echo "n/a n/a"\n');

      final result = run(script.path, ['--min=0']);

      expect(result.exitCode, isNot(0), reason: '${result.stdout}');
      expect('${result.stdout}', contains('Could not measure coverage'));
    });
  });

  group("coverage.yml's check_threshold", () {
    int check(String current, String target) => Process.runSync('bash', [
      '-c',
      '${_checkThreshold()}\ncheck_threshold Total "\$1" "\$2"',
      'check',
      current,
      target,
    ]).exitCode;

    test('an empty or non-numeric measured percentage fails', () {
      expect(check('', '80'), isNot(0));
      expect(check('n/a', '80'), isNot(0));
    });

    test('a non-numeric target fails', () {
      expect(check('95.0', 'abc'), isNot(0));
    });

    test('numbers still compare', () {
      expect(check('95.0', '80'), 0);
      expect(check('79.9', '80'), isNot(0));
    });
  });
}
