// riverpod-retry-policy.md quotes createAppContainer as "the one container
// the app runs on". The quote once showed `overrides: overrides` after the
// real function had started prepending authModuleOverrides, so copying it
// dropped 401 refresh and forced logout. The quote must match the source.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The `ProviderContainer createAppContainer(...) { ... }` declaration in
/// [source], with comments and blank lines removed and indentation dropped.
String _createAppContainer(String source) {
  final start = source.indexOf('ProviderContainer createAppContainer(');
  expect(start, isNot(-1), reason: 'createAppContainer not found');
  // The closing brace alone on its line, not the `}) {` ending the
  // parameter list.
  final end = source.indexOf('\n}\n', start);
  expect(end, isNot(-1), reason: 'createAppContainer has no closing brace');
  return source
      .substring(start, end + 2)
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('//'))
      .join('\n');
}

void main() {
  test(
    'the retry-policy doc quotes createAppContainer as main.dart has it',
    () {
      final source = File('lib/main.dart').readAsStringSync();
      final doc = File(
        'docs/architecture/riverpod-retry-policy.md',
      ).readAsStringSync();

      expect(_createAppContainer(doc), _createAppContainer(source));
    },
  );
}
