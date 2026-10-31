// The pre-commit hook ran `dart format` and `flutter analyze` on the working
// copy. A staged unformatted file whose working copy was fixed but not
// restaged was committed unformatted, and an unstaged broken file blocked a
// clean commit. It now checks the staged content.
//
// Each case builds a throwaway repository: a dependency-free Dart package,
// the real pre-commit hook, and its own global git config, so neither this
// repository nor the user's git config is touched.

@TestOn('!windows')
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final String _hook = File('.githooks/pre-commit').readAsStringSync();

const _unformatted = 'void   probe( ) {  }\n';
const _formatted = 'void probe() {}\n';

void main() {
  late Directory root;
  late String repo;
  late Map<String, String> env;

  ProcessResult git(List<String> args, {String? cwd}) => Process.runSync(
    'git',
    args,
    workingDirectory: cwd ?? repo,
    environment: env,
  );

  void pubGet(String cwd) {
    final result = Process.runSync(
      'dart',
      ['pub', 'get', '--offline'],
      workingDirectory: cwd,
    );
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  }

  void write(String cwd, String path, String content) => File('$cwd/$path')
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  setUp(() {
    root = Directory.systemTemp.createTempSync('pre_commit_staged_');
    repo = '${root.path}/repo';
    final global = File('${root.path}/global.gitconfig')
      ..writeAsStringSync('[user]\n\tname = t\n\temail = t@example.com\n');
    env = {'GIT_CONFIG_GLOBAL': global.path, 'GIT_CONFIG_NOSYSTEM': '1'};
    Directory(repo).createSync();
    git(['init', '-q']);
    write(repo, 'pubspec.yaml', 'name: probe\nenvironment:\n  sdk: ^3.0.0\n');
    write(repo, '.gitignore', '.dart_tool/\npubspec.lock\n');
    write(repo, 'lib/ok.dart', 'int ok() => 1;\n');
    write(repo, '.githooks/pre-commit', _hook);
    Process.runSync('chmod', ['+x', '$repo/.githooks/pre-commit']);
    git(['add', '.']);
    git(['commit', '-q', '--no-verify', '-m', 'chore: initial']);
    git(['config', 'core.hooksPath', '.githooks']);
    pubGet(repo);
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('a staged unformatted file is rejected though the working copy is '
      'fixed', () {
    write(repo, 'lib/probe.dart', _unformatted);
    git(['add', 'lib/probe.dart']);
    write(repo, 'lib/probe.dart', _formatted);

    final result = git(['commit', '-m', 'feat: probe']);

    expect(
      result.exitCode,
      isNot(0),
      reason: '${result.stdout}${result.stderr}',
    );
    expect('${result.stderr}', contains('formatting check failed'));
    expect(
      File('$repo/lib/probe.dart').readAsStringSync(),
      _formatted,
      reason: 'the working copy is not rewritten',
    );
  });

  test('an unstaged broken file does not block a clean staged change', () {
    write(repo, 'lib/ok.dart', 'int ok( => ;\n');
    write(repo, 'lib/clean.dart', _formatted);
    git(['add', 'lib/clean.dart']);

    final result = git(['commit', '-m', 'feat: clean']);

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  });

  test('`git commit <path>` checks the content that path commits', () {
    write(repo, 'lib/ok.dart', 'int   ok( ) => 1;\n');

    final result = git(['commit', '-m', 'feat: x', 'lib/ok.dart']);

    expect(
      result.exitCode,
      isNot(0),
      reason: '${result.stdout}${result.stderr}',
    );
  });

  // A monorepo: the app depends on a package beside the repository through a
  // relative `path:`, which pub records relative to .dart_tool/. Copied into
  // the temporary export unchanged, it resolved to nothing and every commit
  // failed analyze. The space and `#` check paths a URI must escape.
  group('with a path dependency outside the repository', () {
    setUp(() {
      final shared = '${root.path}/shared #lib';
      write(
        shared,
        'pubspec.yaml',
        'name: shared\nenvironment:\n  sdk: ^3.0.0\n',
      );
      write(shared, 'lib/shared.dart', 'int shared() => 1;\n');
      write(
        repo,
        'pubspec.yaml',
        'name: probe\nenvironment:\n  sdk: ^3.0.0\n'
            'dependencies:\n  shared:\n    path: "../shared #lib"\n',
      );
      write(
        repo,
        'lib/uses_shared.dart',
        "import 'package:shared/shared.dart';\n\nint uses() => shared();\n",
      );
      git(['add', '.']);
      git(['commit', '-q', '--no-verify', '-m', 'chore: depend on shared']);
      pubGet(repo);
    });

    test('a clean staged change commits', () {
      write(repo, 'lib/clean.dart', _formatted);
      git(['add', 'lib/clean.dart']);

      final result = git(['commit', '-m', 'feat: clean']);

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    });

    test('a staged format or analyze violation still fails', () {
      write(repo, 'lib/probe.dart', _unformatted);
      git(['add', 'lib/probe.dart']);
      final format = git(['commit', '-m', 'feat: probe']);
      expect(format.exitCode, isNot(0), reason: '${format.stdout}');

      write(repo, 'lib/probe.dart', 'int probe() => nope;\n');
      git(['add', 'lib/probe.dart']);
      final analyze = git(['commit', '-m', 'feat: probe']);
      expect(analyze.exitCode, isNot(0), reason: '${analyze.stdout}');
      expect('${analyze.stderr}${analyze.stdout}', contains('flutter analyze'));
    });
  });

  test('an hour-old export a killed run left beside the repository is '
      'swept, a fresh one is kept', () {
    final stale = Directory('${root.path}/.repo-pre-commit.stale1')
      ..createSync();
    final fresh = Directory('${root.path}/.repo-pre-commit.fresh1')
      ..createSync();
    Process.runSync('touch', ['-t', '202601010000', stale.path]);
    write(repo, 'lib/clean.dart', _formatted);
    git(['add', 'lib/clean.dart']);

    final result = git(['commit', '-m', 'feat: clean']);

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(stale.existsSync(), isFalse);
    expect(fresh.existsSync(), isTrue);
  });

  test('a parent it cannot write to falls back to the temp directory and '
      'says so', () {
    Process.runSync('chmod', ['a-w', root.path]);
    addTearDown(() => Process.runSync('chmod', ['u+w', root.path]));
    write(repo, 'lib/clean.dart', _formatted);
    git(['add', 'lib/clean.dart']);

    final result = git(['commit', '-m', 'feat: clean']);

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(
      '${result.stdout}${result.stderr}',
      contains('Cannot write beside the repository'),
    );
  });

  test("inside a linked worktree it checks that worktree's index", () {
    final worktree = '${root.path}/wt';
    expect(git(['worktree', 'add', '-q', worktree]).exitCode, 0);
    pubGet(worktree);

    write(worktree, 'lib/probe.dart', _unformatted);
    git(['add', 'lib/probe.dart'], cwd: worktree);
    final bad = git(['commit', '-m', 'feat: probe'], cwd: worktree);
    expect(bad.exitCode, isNot(0), reason: '${bad.stdout}${bad.stderr}');

    write(worktree, 'lib/probe.dart', _formatted);
    git(['add', 'lib/probe.dart'], cwd: worktree);
    final good = git(['commit', '-m', 'feat: probe'], cwd: worktree);
    expect(good.exitCode, 0, reason: '${good.stdout}${good.stderr}');
  });
}
