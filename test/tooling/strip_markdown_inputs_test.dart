// The Strip jobs skip strip, analyze and test on a pull request that changes
// only markdown, and leave that markdown to the Quality gate's doc tests. Two
// of their steps read markdown that no doc test covered, so a docs-only pull
// request could break them with every required check green:
//
// - renamed-both runs the rename recipe it extracts from
//   fork-and-customize.md. A recipe missing a directory left
//   `tool/golden/` importing the old package, and the renamed, stripped tree
//   failed `flutter pub get`.
// - every sample variant runs check_docs.dart on the stripped tree. A link to
//   a file the strip deletes passed on the full tree and dangled after it.
//
// Both are repeated here on a copy of the working tree, which is fast enough
// to run on every pull request, docs-only ones included.
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final String _packages = File(
  '.dart_tool/package_config.json',
).absolute.path;

const _recipeDoc = 'docs/guides/onboarding/fork-and-customize.md';

/// How strip-smoke.yml's renamed-both step pulls the recipe out of
/// [_recipeDoc]. The test runs the same pipeline, and checks the workflow
/// still uses it, so the two cannot drift apart.
const _extractRecipe = r"""
awk '/^   NEW=your_package$/{f=1} f{print} f&&/perl -pi/{exit}' "$doc" \
            | sed 's/^   //; s/^NEW=your_package$/NEW=my_app/'""";

/// The import prefix the recipe renames. Split so the recipe, which rewrites
/// it in `test/`, leaves this file's own copy alone.
const _oldImport =
    'package:'
    'flutter_starter/';

/// What the recipe may leave behind: the setup brick's own rename source
/// (fork-and-customize.md says so).
const _allowedLeftovers = 'bricks/flutter_starter_setup/';

/// A git repository holding the working tree's tracked and untracked,
/// not-ignored files, so uncommitted doc edits are what gets checked.
Directory _copyOfWorkingTree() {
  final root = Directory.systemTemp.createTempSync('strip_md_inputs_');
  void check(ProcessResult result, String what) {
    if (result.exitCode == 0) return;
    root.deleteSync(recursive: true);
    fail(
      '$what exited ${result.exitCode}\n'
      'stdout: ${result.stdout}\nstderr: ${result.stderr}',
    );
  }

  final listed = Process.runSync('git', [
    'ls-files',
    '-z',
    '--cached',
    '--others',
    '--exclude-standard',
  ]);
  check(listed, 'git ls-files');
  final files = '${listed.stdout}'
      .split('\u0000')
      .where((f) => f.isNotEmpty && File(f).existsSync())
      .toSet();
  final list = File('${root.path}.list')..writeAsStringSync(files.join('\n'));
  final archive = '${root.path}.tar';
  final packed = Process.runSync('tar', ['-cf', archive, '-T', list.path]);
  list.deleteSync();
  check(packed, 'tar -cf');
  final unpacked = Process.runSync('tar', ['-xf', archive, '-C', root.path]);
  File(archive).deleteSync();
  check(unpacked, 'tar -xf');

  for (final args in [
    ['init', '-q'],
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
    check(
      Process.runSync('git', args, workingDirectory: root.path),
      'git ${args.join(' ')}',
    );
  }
  return root;
}

String _out(ProcessResult r) => 'exit ${r.exitCode}\n${r.stdout}${r.stderr}';

void main() {
  final skip = File('tool/strip_sample_features.dart').existsSync()
      ? null
      : 'the strip tool has been removed';

  Directory? current;
  tearDown(() {
    final dir = current;
    current = null;
    if (dir != null && dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('strip-smoke.yml extracts the rename recipe the way this test does', () {
    expect(
      File('.github/workflows/strip-smoke.yml').readAsStringSync(),
      contains(_extractRecipe),
      reason:
          'renamed-both changed how it reads the recipe; change '
          '_extractRecipe to match',
    );
  }, skip: skip);

  test('the documented rename recipe renames every package import', () {
    final root = current = _copyOfWorkingTree();

    final rename = Process.runSync(
      'bash',
      [
        '-c',
        r'''
set -euo pipefail
eval "$EXTRACT" > "$RECIPE"
grep -q 'perl -pi' "$RECIPE"
bash -euo pipefail "$RECIPE"
''',
      ],
      workingDirectory: root.path,
      environment: {
        'doc': _recipeDoc,
        'EXTRACT': _extractRecipe,
        'RECIPE': '${root.path}.rename.sh',
      },
    );
    final recipe = File('${root.path}.rename.sh');
    if (recipe.existsSync()) recipe.deleteSync();
    expect(rename.exitCode, 0, reason: _out(rename));

    final grep = Process.runSync('git', [
      'grep',
      '-l',
      _oldImport,
      '--',
      '*.dart',
      '*.sh',
      '*.ps1',
    ], workingDirectory: root.path);
    final left = '${grep.stdout}'
        .split('\n')
        .where((f) => f.isNotEmpty && !f.startsWith(_allowedLeftovers))
        .toList();
    expect(
      left,
      isEmpty,
      reason:
          'After the rename recipe in $_recipeDoc these files still import '
          '$_oldImport, so a renamed tree fails `flutter pub get`. Add their '
          'directory to the recipe.',
    );
  }, skip: skip);

  // Each Strip job that runs check_docs.dart after its strip.
  for (final flags in [
    <String>[],
    ['--remove-tasks'],
    ['--remove-feature-flags'],
    ['--keep-samples', '--remove-bricks'],
  ]) {
    test('docs still check after `--apply ${flags.join(' ')}`', () {
      final root = current = _copyOfWorkingTree();

      final strip = Process.runSync('dart', [
        '--packages=$_packages',
        'tool/strip_sample_features.dart',
        '--apply',
        ...flags,
      ], workingDirectory: root.path);
      expect(strip.exitCode, 0, reason: _out(strip));

      final docs = Process.runSync('dart', [
        '--packages=$_packages',
        'tool/check_docs.dart',
      ], workingDirectory: root.path);
      expect(
        docs.exitCode,
        0,
        reason:
            'The stripped tree fails check_docs.dart. A link the strip leaves '
            'dangling belongs inside the matching strip marker.\n${_out(docs)}',
      );
    }, skip: skip);
  }
}
