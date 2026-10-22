// test_coverage.sh must report the numbers CI enforces.
//
// Its --analyze figures came from `grep ... -A 1000`, which counted the next
// thousand lines after every matching file, so other files' lines spilled
// into each layer. --exclude was parsed and never read, and the overall
// figure included generated files that CI's coverage.yml removes first.
@TestOn('mac-os || linux')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// One lcov record: [hits] lists each executable line's hit count.
String _record(String path, List<int> hits) => [
  'SF:$path',
  for (var i = 0; i < hits.length; i++) 'DA:${i + 1},${hits[i]}',
  'LF:${hits.length}',
  'LH:${hits.where((h) => h > 0).length}',
  'end_of_record',
].join('\n');

/// The fixture from the issue, plus a generated file CI always removes:
/// - domain/a.dart 2/2, data/b.dart 0/4, generated/x.dart 0/2,
/// - data/b.g.dart 0/3, excluded by default like coverage.yml does.
final String _fixture = [
  _record('lib/features/auth/domain/a.dart', [1, 3]),
  _record('lib/features/auth/data/b.dart', [0, 0, 0, 0]),
  _record('lib/generated/x.dart', [0, 0]),
  _record('lib/features/auth/data/b.g.dart', [0, 0, 0]),
].join('\n');

void main() {
  final repo = Directory.current.path;
  late Directory workdir;

  setUp(() {
    workdir = Directory.systemTemp.createTempSync('test_coverage_script');
    Directory('${workdir.path}/coverage').createSync();
    File('${workdir.path}/coverage/lcov.info').writeAsStringSync('$_fixture\n');
  });

  tearDown(() => workdir.deleteSync(recursive: true));

  Future<String> run(List<String> args) async {
    final result = await Process.run(
      'bash',
      ['$repo/scripts/test/test_coverage.sh', '--no-test', ...args],
      workingDirectory: workdir.path,
    );
    // Strip ANSI colours so the assertions read the text.
    return '${result.stdout}${result.stderr}'.replaceAll(
      RegExp(r'\x1B\[[0-9;]*m'),
      '',
    );
  }

  Future<String> layer(String pattern, String file) async {
    final result = await Process.run('bash', [
      '$repo/scripts/test/calculate_layer_coverage.sh',
      '--pattern=$pattern',
      file,
    ]);
    return (result.stdout as String).trim();
  }

  group('criterion 2: --exclude removes files', () {
    test('without it, generated code drops out as it does in CI', () async {
      final out = await run([]);
      // coverage.yml removes **/generated/** and **/*.g.dart before gating,
      // so lib/generated/x.dart and b.g.dart drop out: a 2/2 + b 0/4 = 2/6.
      expect(out, contains('Coverage: 33.33%'), reason: out);
      expect(out, contains('Total lines: 6'), reason: out);
    });

    test('--exclude=lib/generated gives 2/6 = 33.33%', () async {
      final out = await run(['--exclude=lib/generated']);
      expect(out, contains('Coverage: 33.33%'), reason: out);
    });

    test('excluding the data file too gives 100%', () async {
      final out = await run([
        '--exclude=lib/generated',
        '--exclude=lib/features/auth/data',
        '--min=60',
      ]);
      expect(out, contains('Coverage: 100.00%'), reason: out);
      expect(out, contains('meets minimum threshold'), reason: out);
    });
  });

  group('criterion 1: --analyze agrees with calculate_layer_coverage.sh', () {
    test('per-layer counts are per file, not spilled', () async {
      final out = await run(['--analyze', '--exclude=lib/generated']);
      final filtered = '${workdir.path}/coverage/lcov.filtered.info';

      expect(await layer('/features/.*/domain/', filtered), '2 2');
      expect(await layer('/features/.*/data/', filtered), '0 4');
      expect(out, contains('Overall: 2/2 lines (100.0%)'), reason: out);
      expect(out, contains('Overall: 0/4 lines (0.0%)'), reason: out);
      // The lcov file CI gates on reports the same layer figures.
      final ci = await Process.run('bash', [
        '$repo/scripts/test/calculate_layer_coverage.sh',
        filtered,
      ]);
      expect(ci.stdout, contains('Domain:       100.0%'));
      expect(ci.stdout, contains('Data:         0.0%'));
    });

    test('the low-coverage list names the right file', () async {
      final out = await run(['--analyze', '--exclude=lib/generated']);
      final low = out.split('Files with Low Coverage').last;

      expect(low, contains('lib/features/auth/data/b.dart: 0.0%'));
      expect(low, isNot(contains('domain/a.dart')));
      expect(low, isNot(contains('b.g.dart')));
    });
  });
}
