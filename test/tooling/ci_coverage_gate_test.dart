// The Quality gate enforces a total line coverage floor on every PR, counted by
// scripts/test/test_coverage.sh. The weekly coverage.yml removes generated and
// test-only files with `lcov --remove` before it measures; the per-PR gate
// must drop the same files, or the two report different numbers for the same
// tree and a floor tuned against one is wrong for the other.
@TestOn('mac-os || linux')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The `- name: <name>` step body in [workflow], up to the next step.
String? _step(String workflow, String name) => RegExp(
  '- name: ${RegExp.escape(name)}\\n(.*?)(?=\\n      - name: |\\n\\S|\$)',
  dotAll: true,
).firstMatch(workflow)?.group(1);

/// The quoted globs coverage.yml passes to `lcov --remove`.
List<String> _lcovRemovePatterns() {
  final yml = File('.github/workflows/coverage.yml').readAsStringSync();
  final block = RegExp(
    r'lcov --remove coverage/lcov\.info.*?-o coverage/lcov\.info',
    dotAll: true,
  ).firstMatch(yml)?.group(0);
  if (block == null) return const [];
  return [for (final m in RegExp("'([^']+)'").allMatches(block)) m.group(1)!];
}

/// A `lib/`-rooted path that [glob] matches, e.g. `**/*.g.dart` ->
/// `lib/x.g.dart`, `**/generated/**` -> `lib/generated/x.dart`.
String _samplePath(String glob) {
  var path = glob.startsWith('**/') ? 'lib/${glob.substring(3)}' : glob;
  if (path.endsWith('/**')) {
    path = '${path.substring(0, path.length - 3)}/x.dart';
  }
  return path.replaceAll('*', 'x');
}

String _record(String path, {required bool covered}) => [
  'SF:$path',
  'DA:1,${covered ? 1 : 0}',
  'LF:1',
  'LH:${covered ? 1 : 0}',
  'end_of_record',
].join('\n');

void main() {
  final repo = Directory.current.path;
  final ci = File('.github/workflows/ci.yml').readAsStringSync();
  final tests = _step(ci, 'Run tests (random order)');
  final gate = _step(ci, 'Enforce minimum coverage');

  test('the Quality gate collects coverage while it runs the suite', () {
    expect(tests, isNotNull, reason: 'ci.yml has no "Run tests" step');
    expect(tests, contains('flutter test --coverage'));
  });

  test('a coverage step fails the gate below a numeric floor', () {
    expect(gate, isNotNull, reason: 'ci.yml has no "Enforce minimum coverage"');
    final floor = RegExp(
      r'COVERAGE_MIN_TOTAL: (\d+(?:\.\d+)?)',
    ).firstMatch(gate!)?.group(1);
    expect(floor, isNotNull, reason: 'COVERAGE_MIN_TOTAL is not a number');
    expect(double.parse(floor!), inInclusiveRange(1, 100));
    expect(
      gate,
      contains(
        r'test_coverage.sh --no-test --min="$COVERAGE_MIN_TOTAL"',
      ),
    );
    // Actions runs bash with -e, so without set +e a failing check would
    // exit before reporting the figure and the annotation.
    expect(gate, contains('set +e'));
    expect(gate, contains(r'status=${PIPESTATUS[0]}'));
    expect(gate, contains('::error title=Coverage below minimum::'));
    expect(gate, contains(r'exit "$status"'));
    expect(gate, contains("if: steps.scope.outputs.run == 'true'"));
  });

  group('test_coverage.sh drops every file coverage.yml removes', () {
    final patterns = _lcovRemovePatterns();
    late Directory workdir;

    setUp(() {
      workdir = Directory.systemTemp.createTempSync('ci_coverage_gate');
      Directory('${workdir.path}/coverage').createSync();
    });

    tearDown(() => workdir.deleteSync(recursive: true));

    test('coverage.yml still lists its exclusions', () {
      expect(patterns, contains('**/*.g.dart'));
      expect(patterns, contains('**/*.freezed.dart'));
    });

    for (final glob in _lcovRemovePatterns()) {
      test(glob, () async {
        // One covered line that must stay, one uncovered line that must go.
        File('${workdir.path}/coverage/lcov.info').writeAsStringSync(
          '${_record('lib/kept.dart', covered: true)}\n'
          '${_record(_samplePath(glob), covered: false)}\n',
        );
        final result = await Process.run(
          'bash',
          ['$repo/scripts/test/test_coverage.sh', '--no-test', '--min=100'],
          workingDirectory: workdir.path,
        );
        final out = '${result.stdout}${result.stderr}';
        expect(
          out,
          contains('Total lines: 1'),
          reason: '${_samplePath(glob)} was counted:\n$out',
        );
        expect(result.exitCode, 0, reason: out);
      });
    }
  });
}
