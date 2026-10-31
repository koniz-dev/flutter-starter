// strip_sample_features.dart could not be re-run after a failure, and
// trusted the current directory:
// (a) a git-ignored file still importing a sample (the coverage helper)
//     failed the forbidden-reference scan after the feature was deleted,
//     leaving a half-stripped tree;
// (b) a re-run after such a partial strip crashed on a patch step whose
//     section was already gone;
// (c) run from test/, it wrote test/lib/... and test/test/... and crashed.
//
// Each case strips a copy of the committed tree, never the repository.
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final String _packages = File(
  '.dart_tool/package_config.json',
).absolute.path;

/// A git repository holding HEAD's tracked files.
Directory _copyOfHead() {
  final root = Directory.systemTemp.createTempSync('strip_rerun_');
  final archive = '${root.path}.tar';
  final made = Process.runSync('git', ['archive', '-o', archive, 'HEAD']);
  expect(made.exitCode, 0, reason: '${made.stderr}');
  final unpacked = Process.runSync('tar', ['-xf', archive, '-C', root.path]);
  expect(unpacked.exitCode, 0, reason: '${unpacked.stderr}');
  File(archive).deleteSync();
  final init = Process.runSync('git', [
    'init',
    '-q',
  ], workingDirectory: root.path);
  expect(init.exitCode, 0, reason: '${init.stderr}');
  return root;
}

ProcessResult _strip(Directory cwd, Directory root, List<String> args) =>
    Process.runSync('dart', [
      '--packages=$_packages',
      '${root.path}/tool/strip_sample_features.dart',
      '--apply',
      ...args,
    ], workingDirectory: cwd.path);

String _out(ProcessResult r) => 'exit ${r.exitCode}\n${r.stdout}${r.stderr}';

/// A Dart file importing the tasks sample. Built from parts so this file,
/// which the strip scans too, never holds the import path itself.
final String _importsTasks = [
  "import 'package:flutter_starter/features/",
  "tasks/domain/entities/task.dart';\n",
  'void main() {}\n',
].join();

void main() {
  final skip = File('tool/strip_sample_features.dart').existsSync()
      ? null
      : 'the strip tool has been removed';

  late Directory root;
  setUp(() {
    if (skip == null) root = _copyOfHead();
  });
  tearDown(() {
    if (skip == null) root.deleteSync(recursive: true);
  });

  test(
    '(a) a git-ignored file importing the sample does not fail the strip',
    () {
      // The coverage helper is generated and git-ignored.
      File('${root.path}/test/coverage_helper_test.dart')
          .writeAsStringSync(_importsTasks);

      final result = _strip(root, root, ['--remove-tasks']);

      expect(result.exitCode, 0, reason: _out(result));
      expect(
        Directory('${root.path}/lib/features/tasks').existsSync(),
        isFalse,
      );
    },
    skip: skip,
  );

  test('(b) a re-run after a partial strip completes', () {
    // A tracked-looking stray reference stops the first run after it has
    // deleted the feature and patched the helpers.
    final stray = File('${root.path}/test/stray_test.dart')
      ..writeAsStringSync(_importsTasks);
    final first = _strip(root, root, ['--remove-tasks']);
    expect(first.exitCode, 3, reason: _out(first));

    stray.deleteSync();
    final second = _strip(root, root, ['--remove-tasks']);

    expect(second.exitCode, 0, reason: _out(second));
  }, skip: skip);

  test('(c) a run from a subdirectory refuses and writes nothing', () {
    final test = Directory('${root.path}/test');

    final result = _strip(test, root, ['--remove-tasks']);

    expect(result.exitCode, 2, reason: _out(result));
    expect('${result.stderr}', contains('Run this from the project root'));
    expect(Directory('${test.path}/lib').existsSync(), isFalse);
    expect(Directory('${test.path}/test').existsSync(), isFalse);
    expect(Directory('${root.path}/lib/features/tasks').existsSync(), isTrue);
  }, skip: skip);
}
