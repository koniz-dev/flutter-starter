// The Quality gate and Strip smoke skip their work when a PR changes only
// markdown and docs/. They list the changed paths with `git diff --name-only`,
// which detects renames: a `.dart` file moved to `docs/notes.md` was listed
// only under its new name, so a PR that deleted Dart source was classified
// docs-only. This runs each workflow's own command on such a move.

@TestOn('!windows')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The `changed="$(git diff ...)"` command a workflow decides its scope with.
String _diffCommand(String workflow) {
  final match = RegExp(
    r'changed="\$\((git diff [^)]*)\)"',
  ).firstMatch(File(workflow).readAsStringSync());
  if (match == null) throw StateError('$workflow lists no changed paths');
  return match.group(1)!;
}

void main() {
  late Directory repo;

  ProcessResult git(List<String> args) =>
      Process.runSync('git', args, workingDirectory: repo.path);

  setUpAll(() {
    repo = Directory.systemTemp.createTempSync('gate_scope_');
    git(['init', '-q']);
    git(['config', 'user.email', 'test@example.com']);
    git(['config', 'user.name', 'test']);
    git(['config', 'commit.gpgsign', 'false']);
    Directory('${repo.path}/lib').createSync();
    File('${repo.path}/lib/a.dart').writeAsStringSync(
      List.generate(40, (i) => '// line $i of a source file').join('\n'),
    );
    git(['add', '.']);
    git(['commit', '-q', '--no-verify', '-m', 'base']);
    Directory('${repo.path}/docs').createSync();
    git(['mv', 'lib/a.dart', 'docs/a.md']);
    git(['commit', '-q', '--no-verify', '-m', 'move']);
  });

  tearDownAll(() => repo.deleteSync(recursive: true));

  for (final workflow in [
    '.github/workflows/ci.yml',
    '.github/workflows/strip-smoke.yml',
  ]) {
    // The sample strip deletes strip-smoke.yml along with itself.
    final skip = File(workflow).existsSync() ? null : '$workflow was removed';
    test('$workflow lists both sides of a rename', skip: skip, () {
      final command = _diffCommand(
        workflow,
      ).replaceAll(r'"$range"', 'HEAD~1..HEAD');
      final result = Process.runSync('bash', [
        '-c',
        command,
      ], workingDirectory: repo.path);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(
        (result.stdout as String).split('\n'),
        containsAll(['lib/a.dart', 'docs/a.md']),
        reason: 'the moved Dart file must count as changed',
      );
    });
  }
}
