// setup_git_hooks.sh copied the hooks into .git/hooks/ and printed
// "installed", but git ignores that directory whenever core.hooksPath is set
// - a global setting, a husky-style setup - so nothing ran: a commit with a
// non-conventional message went through. Inside a linked worktree it failed
// with "Not a Git repository". It now points core.hooksPath at .githooks/.
//
// Each case builds a throwaway repository holding the script, the real
// commit-msg hook and stub pre-commit/pre-push hooks (the real ones run
// Flutter), with its own global config file, so neither this repository nor
// the user's git config is touched. A hook that really runs is proven by
// commit-msg rejecting a message.

@TestOn('!windows')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final String _script = File('scripts/dev/setup_git_hooks.sh')
    .readAsStringSync();
final String _commitMsg = File('.githooks/commit-msg').readAsStringSync();

void main() {
  late Directory root;
  late Map<String, String> env;

  ProcessResult git(List<String> args, {String? cwd}) => Process.runSync(
    'git',
    args,
    workingDirectory: cwd ?? '${root.path}/repo',
    environment: env,
  );

  ProcessResult setup({String? cwd}) => Process.runSync(
    'bash',
    ['scripts/dev/setup_git_hooks.sh'],
    workingDirectory: cwd ?? '${root.path}/repo',
    environment: env,
  );

  setUp(() {
    root = Directory.systemTemp.createTempSync('git_hooks_setup_');
    final global = File('${root.path}/global.gitconfig')
      ..writeAsStringSync('[user]\n\tname = t\n\temail = t@example.com\n');
    env = {
      'GIT_CONFIG_GLOBAL': global.path,
      'GIT_CONFIG_NOSYSTEM': '1',
      'HOME': root.path,
    };
    final repo = Directory('${root.path}/repo')..createSync();
    git(['init', '-q']);
    File('${repo.path}/scripts/dev/setup_git_hooks.sh')
      ..createSync(recursive: true)
      ..writeAsStringSync(_script);
    for (final (name, body) in [
      ('commit-msg', _commitMsg),
      ('pre-commit', '#!/usr/bin/env bash\nexit 0\n'),
      ('pre-push', '#!/usr/bin/env bash\nexit 0\n'),
    ]) {
      final hook = File('${repo.path}/.githooks/$name')
        ..createSync(recursive: true)
        ..writeAsStringSync(body);
      Process.runSync('chmod', ['+x', hook.path]);
    }
    git(['add', '.']);
    git(['commit', '-q', '--no-verify', '-m', 'chore: initial']);
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('with a global core.hooksPath, the hooks still run afterwards', () {
    git(['config', '--global', 'core.hooksPath', '${root.path}/elsewhere']);

    final result = setup();

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect('${result.stdout}', contains('overrides your global'));
    final bad = git(['commit', '--allow-empty', '-m', 'not conventional']);
    expect(bad.exitCode, isNot(0), reason: 'commit-msg must have run');
    final good = git(['commit', '--allow-empty', '-m', 'feat: conventional']);
    expect(good.exitCode, 0, reason: '${good.stdout}${good.stderr}');
  });

  test('a repository-local core.hooksPath elsewhere is not overwritten', () {
    git(['config', '--local', 'core.hooksPath', 'my-hooks']);

    final result = setup();

    expect(result.exitCode, isNot(0));
    expect('${result.stdout}', contains("'my-hooks'"));
    expect(
      '${git(['config', '--local', '--get', 'core.hooksPath']).stdout}'.trim(),
      'my-hooks',
    );
  });

  test('with the app in a subdirectory of a larger repository, hooks run', () {
    // A monorepo: the git repository is one level above the app.
    final mono = Directory('${root.path}/mono')..createSync();
    git(['init', '-q'], cwd: mono.path);
    final copied = Process.runSync('cp', [
      '-R',
      '${root.path}/repo',
      '${mono.path}/app',
    ]);
    expect(copied.exitCode, 0, reason: '${copied.stderr}');
    Directory('${mono.path}/app/.git').deleteSync(recursive: true);
    git(['add', '.'], cwd: mono.path);
    git([
      'commit',
      '-q',
      '--no-verify',
      '-m',
      'chore: initial',
    ], cwd: mono.path);

    final result = setup(cwd: '${mono.path}/app');

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    String hooksPath() =>
        '${git([
              'config',
              '--local',
              '--get',
              'core.hooksPath',
            ], cwd: mono.path).stdout}'
            .trim();
    expect(hooksPath(), 'app/.githooks');
    for (final cwd in [mono.path, '${mono.path}/app']) {
      final bad = git([
        'commit',
        '--allow-empty',
        '-m',
        'not conventional',
      ], cwd: cwd);
      expect(bad.exitCode, isNot(0), reason: 'commit-msg must run from $cwd');
    }

    // An earlier version wrote a bare `.githooks` here, which named nothing:
    // a re-run replaces it rather than refusing it as someone else's.
    git(['config', '--local', 'core.hooksPath', '.githooks'], cwd: mono.path);
    final rerun = setup(cwd: '${mono.path}/app');
    expect(rerun.exitCode, 0, reason: '${rerun.stdout}${rerun.stderr}');
    expect(hooksPath(), 'app/.githooks');
  });

  test('a failed verification puts the previous core.hooksPath back', () {
    // A command-scope setting outranks the local one, so git keeps resolving
    // hooks elsewhere after the script writes its own.
    final override = {
      ...env,
      'GIT_CONFIG_COUNT': '1',
      'GIT_CONFIG_KEY_0': 'core.hooksPath',
      'GIT_CONFIG_VALUE_0': '${root.path}/elsewhere',
    };
    String? local() {
      final got = git(['config', '--local', '--get', 'core.hooksPath']);
      return got.exitCode == 0 ? '${got.stdout}'.trim() : null;
    }

    ProcessResult failingSetup() => Process.runSync(
      'bash',
      ['scripts/dev/setup_git_hooks.sh'],
      workingDirectory: '${root.path}/repo',
      environment: override,
    );

    final unset = failingSetup();
    expect(unset.exitCode, isNot(0));
    expect('${unset.stdout}', contains('restored'));
    expect(local(), isNull);

    git(['config', '--local', 'core.hooksPath', '.githooks']);
    expect(failingSetup().exitCode, isNot(0));
    expect(local(), '.githooks');
  });

  test('the PowerShell twin prefixes the path and restores on failure', () {
    // No PowerShell runs here; this reads the script.
    final ps1 = File('scripts/dev/setup_git_hooks.ps1').readAsStringSync();
    expect(ps1, contains("(git rev-parse --show-prefix) + '.githooks'"));
    expect(ps1, contains(r'git config --local core.hooksPath $hooksPath'));
    expect(ps1, contains('git config --local --unset core.hooksPath'));
    expect(ps1, contains(r"$localPath -ne '.githooks'"));
    expect(ps1, contains(r'git config --local core.hooksPath $localPath'));
  });

  test('running it twice succeeds both times', () {
    expect(setup().exitCode, 0);
    expect(setup().exitCode, 0);
    final bad = git(['commit', '--allow-empty', '-m', 'not conventional']);
    expect(bad.exitCode, isNot(0));
  });

  test('inside a linked worktree it installs, and hooks run there', () {
    final worktree = '${root.path}/wt';
    expect(git(['worktree', 'add', '-q', worktree]).exitCode, 0);

    final result = setup(cwd: worktree);

    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    final bad = git([
      'commit',
      '--allow-empty',
      '-m',
      'not conventional',
    ], cwd: worktree);
    expect(bad.exitCode, isNot(0));
  });

  test("names a hook in the repository's hooks directory that will stop "
      'running', () {
    final hooks = Directory('${root.path}/repo/.git/hooks')
      ..createSync(recursive: true);
    for (final name in ['post-checkout', 'pre-commit', 'pre-rebase.sample']) {
      final hook = File('${hooks.path}/$name')
        ..writeAsStringSync('#!/usr/bin/env bash\nexit 0\n');
      Process.runSync('chmod', ['+x', hook.path]);
    }

    final result = setup();

    expect(result.exitCode, 0, reason: '${result.stderr}');
    final out = '${result.stdout}';
    expect(out, contains('no longer run'));
    // Only post-checkout: .githooks/ has a pre-commit, and a sample never
    // runs anyway.
    final listed = out
        .split('\n')
        .firstWhere((line) => line.contains('instead: '))
        .split('instead: ')
        .last
        .trim();
    expect(listed, 'post-checkout');
  });

  test('says nothing about hooks when there are none to lose', () {
    final result = setup();

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect('${result.stdout}', isNot(contains('no longer run')));
  });
}
