// SecureStorageService.clear() deletes outside SecureTokenStore's operation
// queue, so a logout built on it would reopen the web race in which a pending
// token write lands after the clear. Nothing in lib/ may call it on a secure
// storage service; sessions end through ITokenStore.clearAllTokens.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no code in lib/ calls clear() on a secure storage service', () {
    final callers = <String>[
      for (final file
          in Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart')))
        for (final (index, line) in file.readAsLinesSync().indexed)
          if (RegExp(
            r'secure\w*\s*[.?]+\s*clear\(\)',
            caseSensitive: false,
          ).hasMatch(line))
            '${file.path}:${index + 1}: ${line.trim()}',
    ];

    expect(callers, isEmpty);
  });
}
