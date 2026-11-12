// `patrol test` exits 0 when it collected no test, and when every test was
// skipped. The E2E workflow's guard checked only "Total > 0" and
// "Failed == 0", so a run reporting "Total: 2 ... Skipped: 2" was green having
// verified nothing, and the local script had no guard at all. Both now run
// scripts/test/check_patrol_summary.sh, which passes only when every
// collected test ran and passed.
@TestOn('!windows')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The summary block as patrol_cli 4 prints it.
String _summary({
  required int total,
  required int successful,
  int failed = 0,
  int skipped = 0,
}) =>
    '''
Test summary:
📝 Total: $total
✅ Successful: $successful
❌ Failed: $failed
⏩ Skipped: $skipped
📊 Report: file:///build/app/reports/androidTests/connected/debug/index.html
⏱️  Duration: 18m 52s
''';

/// Runs the check on a log holding [output], or on a missing log when null.
Future<ProcessResult> _check(String? output) {
  final dir = Directory.systemTemp.createTempSync('patrol_summary_');
  addTearDown(() => dir.deleteSync(recursive: true));
  final log = File('${dir.path}/patrol-output.log');
  if (output != null) log.writeAsStringSync(output);
  return Process.run(
    'bash',
    ['scripts/test/check_patrol_summary.sh', log.path],
    environment: {'GITHUB_ACTIONS': ''},
  );
}

void main() {
  test('a run where every test passed is accepted', () async {
    final result = await _check(_summary(total: 2, successful: 2));

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect('${result.stdout}', contains('OK: 2 test(s)'));
  });

  test('a run whose tests were all skipped is refused', () async {
    final result = await _check(_summary(total: 2, successful: 0, skipped: 2));

    expect(result.exitCode, isNot(0));
    expect('${result.stderr}', contains('2 of 2 Patrol test(s) were skipped'));
  });

  test('one skipped test among passing ones is refused', () async {
    final result = await _check(_summary(total: 3, successful: 2, skipped: 1));

    expect(result.exitCode, isNot(0));
    expect('${result.stderr}', contains('1 of 3'));
  });

  test('an empty run is refused', () async {
    final result = await _check(_summary(total: 0, successful: 0));

    expect(result.exitCode, isNot(0));
    expect('${result.stderr}', contains('collected 0 tests'));
  });

  test('a failed test is refused', () async {
    final result = await _check(_summary(total: 2, successful: 1, failed: 1));

    expect(result.exitCode, isNot(0));
    expect('${result.stderr}', contains('1 of 2 Patrol test(s) failed'));
  });

  test('fewer successes than tests is refused even with no failure or skip '
      'reported', () async {
    final result = await _check(_summary(total: 2, successful: 1));

    expect(result.exitCode, isNot(0));
    expect('${result.stderr}', contains('Only 1 of 2'));
  });

  test('output with no summary, or no log at all, is refused', () async {
    final noSummary = await _check('Gradle test execution failed\n');
    final noLog = await _check(null);

    expect(noSummary.exitCode, isNot(0));
    expect('${noSummary.stderr}', contains("No 'Total:' summary"));
    expect(noLog.exitCode, isNot(0));
    expect('${noLog.stderr}', contains('is missing'));
  });

  test('the last summary in the log is the one that counts', () async {
    final result = await _check(
      '${_summary(total: 2, successful: 2)}'
      'retrying...\n'
      '${_summary(total: 2, successful: 0, skipped: 2)}',
    );

    expect(result.exitCode, isNot(0));
    expect('${result.stderr}', contains('skipped'));
  });

  test('the workflow and the local script both run the check', () {
    final workflow = File('.github/workflows/e2e-android.yml');
    final local = File('scripts/test/run_e2e_tests.sh').readAsStringSync();

    expect(local, contains(r'check_patrol_summary.sh" "$PATROL_LOG"'));
    expect(local, contains(r'| tee "$PATROL_LOG"'));
    expect(local, contains('set -eo pipefail'));
    if (workflow.existsSync()) {
      expect(
        workflow.readAsStringSync(),
        contains(
          'run: ./scripts/test/check_patrol_summary.sh patrol-output.log',
        ),
      );
    }
  });
}
