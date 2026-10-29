// docs/api/features/auth/providers.md quotes the auth slice's providers.
// Its authRemoteDataSourceProvider and authRepositoryProvider quotes once
// lacked the demo branch, httpCache and sessionGeneration; an override
// copied from them compiled and silently dropped cache clearing on logout
// and the session-generation guard. Every quoted provider declared in
// auth_providers.dart must match its source, comments and indentation
// aside.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The code lines of the `final ... [name] = ...;` declaration in [text],
/// without comments, blank lines or indentation.
String? _declaration(String text, String name) {
  final match = RegExp(
    '^final [^\\n]*\\b$name =[\\s\\S]*?\\n\\s*\\}\\);',
    multiLine: true,
  ).firstMatch(text);
  return match
      ?.group(0)!
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('//'))
      .join('\n');
}

void main() {
  final source = File(
    'lib/features/auth/di/auth_providers.dart',
  ).readAsStringSync();
  final doc = File('docs/api/features/auth/providers.md').readAsStringSync();
  final quoted =
      RegExp(
            r'^### (\w+Provider)$',
            multiLine: true,
          )
          .allMatches(doc)
          .map((m) => m.group(1)!)
          .where(
            (name) => _declaration(source, name) != null,
          );

  test(
    'the doc quotes at least the two providers this test was written for',
    () {
      expect(
        quoted,
        containsAll(['authRemoteDataSourceProvider', 'authRepositoryProvider']),
      );
    },
  );

  for (final name in quoted) {
    test('$name is quoted as auth_providers.dart declares it', () {
      final section = doc.substring(doc.indexOf('### $name\n'));
      expect(_declaration(section, name), _declaration(source, name));
    });
  }
}
