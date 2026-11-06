// commit-msg receives the message before git cleans it up: comment lines
// (a commit.template, the notes `git merge --squash` leaves) and leading blank
// lines are still in the file. The hook read its first line, so a valid
// subject under a template's comment was rejected, as was an unedited squash
// merge. These run the hook on such files, the way git hands them over.

@TestOn('!windows')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('commit_msg_'));
  tearDown(() => dir.deleteSync(recursive: true));

  ProcessResult hook(String message) {
    final file = File('${dir.path}/COMMIT_EDITMSG')..writeAsStringSync(message);
    return Process.runSync('bash', ['.githooks/commit-msg', file.path]);
  }

  /// The hook's exit code for [message].
  int exitFor(String message) => hook(message).exitCode;

  test('a subject under a commit.template comment is read', () {
    expect(exitFor('# Subject: <type>: <summary>\n\nfeat: add login\n'), 0);
    expect(exitFor('# Subject: <type>: <summary>\n\nadd login\n'), isNot(0));
  });

  test('leading blank lines are skipped', () {
    expect(exitFor('\n\n  \nfix: handle a null user\n# Please enter\n'), 0);
    expect(exitFor('\n\nhandle a null user\n'), isNot(0));
  });

  test('an unedited squash merge message is accepted', () {
    expect(
      exitFor(
        'Squashed commit of the following:\n\n'
        'commit 0123456789abcdef\nAuthor: A <a@example.com>\n\n    feat: x\n'
        '# Please enter the commit message for your changes.\n',
      ),
      0,
    );
  });

  test('core.commentString sets the comment prefix', () {
    final repo = Directory('${dir.path}/repo')..createSync();
    Process.runSync('git', ['init', '-q'], workingDirectory: repo.path);
    Process.runSync('git', [
      'config',
      'core.commentString',
      ';',
    ], workingDirectory: repo.path);
    final file = File('${dir.path}/MSG')
      ..writeAsStringSync('; Subject: <type>: <summary>\n\nfeat: x\n');
    final result = Process.runSync('bash', [
      '${Directory.current.path}/.githooks/commit-msg',
      file.path,
    ], workingDirectory: repo.path);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  });

  test('a message of only comments is rejected', () {
    expect(exitFor('# nothing but a comment\n\n'), isNot(0));
  });

  test('a plain conventional subject still passes', () {
    expect(exitFor('feat(auth): add biometric login\n'), 0);
    expect(exitFor('Add biometric login\n'), isNot(0));
  });
}
