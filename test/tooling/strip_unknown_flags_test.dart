// strip_sample_features.dart read its flags with `contains`, so an unknown
// one was dropped in silence: `--keep-sample` (one letter short) or
// `--remove-taks` left neither sample flag set, which means "remove both",
// and the tool deleted both samples, bricks/ and itself.
//
// The tool runs in a throwaway directory holding a sentinel sample, never in
// the repository: if the check ever regressed, only the copy would go.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final String _tool = File('tool/strip_sample_features.dart').absolute.path;
final String _packages = File(
  '.dart_tool/package_config.json',
).absolute.path;

Future<ProcessResult> _run(Directory cwd, List<String> args) {
  return Process.run('dart', [
    '--packages=$_packages',
    _tool,
    ...args,
  ], workingDirectory: cwd.path);
}

void main() {
  late Directory root;
  late File sentinel;

  setUp(() {
    root = Directory.systemTemp.createTempSync('strip_flags_');
    sentinel = File('${root.path}/lib/features/tasks/sentinel.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('// must survive\n');
  });

  tearDown(() => root.deleteSync(recursive: true));

  for (final args in [
    ['--apply', '--keep-sample', '--remove-bricks'],
    ['--apply', '--remove-taks'],
    ['--apply', '--remove-feature-flag'],
  ]) {
    test('${args.join(' ')} exits non-zero, names the flag and deletes '
        'nothing', () async {
      final result = await _run(root, args);

      expect(result.exitCode, isNot(0));
      final bad = args.firstWhere(
        (a) => a != '--apply' && a != '--remove-bricks',
      );
      expect('${result.stderr}', contains(bad));
      expect('${result.stderr}', contains('Nothing was deleted'));
      expect(sentinel.existsSync(), isTrue);
    });
  }

  test('--help prints the usage and exits 0', () async {
    final result = await _run(root, ['--help']);

    expect(result.exitCode, 0);
    expect(
      '${result.stdout}',
      contains('Usage: dart run tool/strip_sample_features.dart'),
    );
    expect(sentinel.existsSync(), isTrue);
  });
}
