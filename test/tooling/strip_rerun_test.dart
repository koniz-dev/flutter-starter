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
  File('${root.path}/tool/strip_sample_features.dart').writeAsBytesSync(
    File('tool/strip_sample_features.dart').readAsBytesSync(),
  );
  final init = Process.runSync('git', [
    'init',
    '-q',
  ], workingDirectory: root.path);
  expect(init.exitCode, 0, reason: '${init.stderr}');
  for (final args in [
    ['add', '--all'],
    [
      '-c',
      'core.hooksPath=/dev/null',
      '-c',
      'user.name=Fixture',
      '-c',
      'user.email=fixture@example.invalid',
      'commit',
      '-qm',
      'baseline',
    ],
  ]) {
    final result = Process.runSync('git', args, workingDirectory: root.path);
    expect(result.exitCode, 0, reason: '${result.stderr}');
  }
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
///
/// The package is the one [root]'s pubspec names, not a literal: after the
/// setup brick renames the working tree, this file names the new package
/// while [_copyOfHead] still holds the committed, unrenamed one, and an
/// import of a package the copy does not have is not a sample reference.
String _importsTasks(Directory root) {
  final pubspec = File('${root.path}/pubspec.yaml').readAsStringSync();
  final name = RegExp(
    r'^name:\s*(\S+)\s*$',
    multiLine: true,
  ).firstMatch(pubspec)!.group(1);
  return [
    "import 'package:$name/features/",
    "tasks/domain/entities/task.dart';\n",
    'void main() {}\n',
  ].join();
}

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
          .writeAsStringSync(_importsTasks(root));

      final result = _strip(root, root, ['--remove-tasks']);

      expect(result.exitCode, 0, reason: _out(result));
      expect('${result.stdout}', contains('git-ignored files'));
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
      ..writeAsStringSync(_importsTasks(root));
    final first = _strip(root, root, ['--remove-tasks', '--force']);
    expect(first.exitCode, 3, reason: _out(first));

    stray.deleteSync();
    final second = _strip(root, root, ['--remove-tasks', '--force']);

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

  for (final mode in [
    'unstaged',
    'staged',
    'untracked',
    'skip-worktree',
    'assume-unchanged',
    'unrelated',
  ]) {
    test('refuses $mode edits before deleting or overwriting anything', () {
      const path = 'lib/core/routing/app_routes.dart';
      final target = File('${root.path}/$path');
      final original = target.readAsStringSync();
      if (mode == 'skip-worktree' || mode == 'assume-unchanged') {
        expect(
          Process.runSync('git', [
            'update-index',
            '--$mode',
            path,
          ], workingDirectory: root.path).exitCode,
          0,
        );
      }
      if (mode == 'untracked') {
        File('${root.path}/custom.txt').writeAsStringSync('my work');
      } else if (mode == 'unrelated') {
        File('${root.path}/README.md')
            .writeAsStringSync('adopter text', mode: FileMode.append);
      } else {
        target.writeAsStringSync('$original\n// adopter edit\n');
      }
      if (mode == 'staged') {
        expect(
          Process.runSync('git', [
            'add',
            path,
          ], workingDirectory: root.path).exitCode,
          0,
        );
      }
      final before = target.readAsStringSync();
      final result = _strip(root, root, ['--remove-tasks']);
      expect(result.exitCode, 2, reason: _out(result));
      expect(
        '${result.stderr}',
        contains(
          mode == 'untracked'
              ? 'custom.txt'
              : mode == 'unrelated'
              ? 'README.md'
              : path,
        ),
      );
      expect('${result.stderr}', contains('--force'));
      expect(target.readAsStringSync(), before);
      expect(Directory('${root.path}/lib/features/tasks').existsSync(), isTrue);
      expect(
        File('${root.path}/tool/strip_sample_features.dart').existsSync(),
        isTrue,
      );
    }, skip: skip);
  }

  test('force permits an intentional overwrite of a dirty tree', () {
    File('${root.path}/lib/core/routing/app_routes.dart')
        .writeAsStringSync('// adopter edit\n');
    final result = _strip(root, root, ['--remove-tasks', '--force']);
    expect(result.exitCode, 0, reason: _out(result));
    expect(Directory('${root.path}/lib/features/tasks').existsSync(), isFalse);
  }, skip: skip);

  test('clean CRLF overwrite targets do not trigger the guard', () {
    expect(
      Process.runSync('git', [
        'config',
        'core.autocrlf',
        'true',
      ], workingDirectory: root.path).exitCode,
      0,
    );
    final paths = [
      for (final name in [
        'app_routes.dart',
        'navigation_extensions.dart',
        'routes_registry.dart',
      ])
        'lib/core/routing/$name',
    ];
    for (final path in paths) {
      File('${root.path}/$path').deleteSync();
    }
    expect(
      Process.runSync('git', [
        'checkout',
        '--',
        ...paths,
      ], workingDirectory: root.path).exitCode,
      0,
    );
    expect(
      File('${root.path}/${paths.first}').readAsStringSync(),
      contains('\r\n'),
    );
    expect(
      Process.runSync('git', [
        'status',
        '--porcelain',
      ], workingDirectory: root.path).stdout,
      isEmpty,
    );
    final result = _strip(root, root, ['--remove-tasks']);
    expect(result.exitCode, 0, reason: _out(result));
  }, skip: skip);

  test('bricks-only removal also refuses a dirty tree', () {
    File('${root.path}/custom.txt').writeAsStringSync('keep me');
    final result = _strip(root, root, ['--keep-samples', '--remove-bricks']);
    expect(result.exitCode, 2, reason: _out(result));
    expect('${result.stderr}', contains('custom.txt'));
    expect(Directory('${root.path}/bricks').existsSync(), isTrue);
  }, skip: skip);

  test('a missing Git baseline refuses unless force is explicit', () {
    Directory('${root.path}/.git').deleteSync(recursive: true);
    final refused = _strip(root, root, ['--remove-tasks']);
    expect(refused.exitCode, 2, reason: _out(refused));
    expect('${refused.stderr}', contains('Cannot verify'));
    expect(Directory('${root.path}/lib/features/tasks').existsSync(), isTrue);
    final forced = _strip(root, root, ['--remove-tasks', '--force']);
    expect(forced.exitCode, 0, reason: _out(forced));
  }, skip: skip);

  test(
    'a clean app nested in a monorepo resolves committed override paths',
    () {
      final app = Directory('${root.path}/app')..createSync();
      for (final entry in root.listSync()) {
        final name = entry.uri.pathSegments
            .where((part) => part.isNotEmpty)
            .last;
        if (name == '.git' || name == 'app') continue;
        entry.renameSync('${app.path}/$name');
      }
      File('${root.path}/.gitattributes').writeAsStringSync(
        'app/lib/core/routing/app_routes.dart text eol=crlf\n',
      );
      for (final args in [
        ['add', '--all'],
        [
          '-c',
          'core.hooksPath=/dev/null',
          '-c',
          'user.name=Fixture',
          '-c',
          'user.email=fixture@example.invalid',
          'commit',
          '-qm',
          'nest app',
        ],
      ]) {
        final result = Process.runSync(
          'git',
          args,
          workingDirectory: root.path,
        );
        expect(result.exitCode, 0, reason: '${result.stderr}');
      }
      final target = File('${app.path}/lib/core/routing/app_routes.dart')
        ..deleteSync();
      expect(
        Process.runSync('git', [
          'checkout',
          '--',
          'app/lib/core/routing/app_routes.dart',
        ], workingDirectory: root.path).exitCode,
        0,
      );
      expect(target.readAsStringSync(), contains('\r\n'));
      expect(
        Process.runSync('git', [
          'status',
          '--porcelain',
        ], workingDirectory: root.path).stdout,
        isEmpty,
      );
      final result = _strip(app, app, ['--remove-tasks']);
      expect(result.exitCode, 0, reason: _out(result));
      expect(Directory('${app.path}/lib/features/tasks').existsSync(), isFalse);
    },
    skip: skip,
  );
}
