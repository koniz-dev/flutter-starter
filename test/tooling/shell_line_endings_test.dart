import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tracked hooks and shell entry points always check out with LF', () {
    final tracked = Process.runSync('git', ['ls-files', '-z']);
    expect(tracked.exitCode, 0, reason: '${tracked.stderr}');
    final shellShebang = RegExp(r'^#![^\r\n]*\b(?:ba|da|k|z)?sh(?:\s|$)');
    final paths = (tracked.stdout as String).split('\x00').where((path) {
      if (path.isEmpty) return false;
      if (path.startsWith('.githooks/') || path.endsWith('.sh')) return true;
      // Include extensionless shell entry points added outside .githooks too.
      final candidate = File(path);
      // Strip tooling may have removed optional tracked files in this worktree.
      if (!candidate.existsSync()) return false;
      final file = candidate.openSync();
      try {
        return shellShebang.hasMatch(String.fromCharCodes(file.readSync(256)));
      } finally {
        file.closeSync();
      }
    }).toList();
    expect(paths, contains('.githooks/commit-msg'));
    expect(paths, contains('scripts/dev/create_feature.sh'));

    final attributes = Process.runSync('git', [
      'check-attr',
      '-z',
      'eol',
      '--',
      ...paths,
    ]);
    expect(attributes.exitCode, 0, reason: '${attributes.stderr}');
    final fields = (attributes.stdout as String).split('\x00')..removeLast();
    expect(fields.length, paths.length * 3);
    for (var i = 0; i < fields.length; i += 3) {
      expect(fields[i + 1], 'eol');
      expect(fields[i + 2], 'lf', reason: '${fields[i]} must check out as LF');
    }
  });
}
