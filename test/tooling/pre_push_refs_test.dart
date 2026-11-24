import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final zero = '0' * 40;
  final sha = '1' * 40;
  final branch = 'refs/heads/main $sha refs/heads/main $zero\n';
  final tag = 'refs/tags/v1 $sha refs/tags/v1 $zero\n';
  final deletion = '(delete) $zero refs/heads/old $sha\n';
  for (final entry in [
    ('branch update', branch, true),
    ('tag only', tag, false),
    ('deletion only', deletion, false),
    ('tag and deletion', '$tag$deletion', false),
    ('branch mixed with tag', '$tag$branch', true),
    (
      'tag pushed to a branch',
      'refs/tags/v1 $sha refs/heads/new $zero\n',
      true,
    ),
    ('manual invocation without refs', '', true),
  ]) {
    test('pre-push ${entry.$1}', () async {
      final root = Directory.systemTemp.createTempSync('pre-push-refs-');
      addTearDown(() => root.deleteSync(recursive: true));
      final hooks = Directory('${root.path}/.githooks')..createSync();
      final bin = Directory('${root.path}/bin')..createSync();
      final hook = File('${hooks.path}/pre-push')
        ..writeAsStringSync(File('.githooks/pre-push').readAsStringSync());
      final calls = File('${root.path}/calls');
      final flutter = File('${bin.path}/flutter')
        ..writeAsStringSync(
          '#!/usr/bin/env bash\nprintf \'%s\\n\' "\$*" >> "\$HOOK_CALLS_FILE"\n',
        );
      expect(Process.runSync('chmod', ['+x', flutter.path]).exitCode, 0);
      final process = await Process.start(
        '/bin/bash',
        [hook.path],
        workingDirectory: root.path,
        environment: {
          'PATH': '${bin.path}:${Platform.environment['PATH']}',
          'HOOK_CALLS_FILE': calls.path,
        },
      );
      final output = process.stdout.transform(utf8.decoder).join();
      final errors = process.stderr.transform(utf8.decoder).join();
      process.stdin.write(entry.$2);
      await process.stdin.close();
      expect(
        await process.exitCode,
        0,
        reason: '${await output}\n${await errors}',
      );
      expect(calls.existsSync(), entry.$3);
      if (entry.$3) {
        expect(calls.readAsLinesSync(), [
          'test --reporter compact --timeout 15m',
        ]);
      }
    }, skip: Platform.isWindows ? 'Bash hooks are tested on Unix hosts' : null);
  }
}
