// The setup docs must tell an Android-emulator user how to reach a backend on
// their machine (koniz-dev/flutter-starter#301).
//
// The development default is http://localhost:3000, and on an Android
// emulator localhost is the emulator itself. Nothing in the setup docs said
// so, and an adopter following getting-started against a local backend got
// connection failures with nothing pointing at the cause. This fails if the
// note is removed from either guide.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _files = [
  'docs/guides/onboarding/getting-started.md',
  'docs/guides/configuration.md',
  // The BASE_URL comment (koniz-dev/flutter-starter#493).
  '.env.example',
];

void main() {
  for (final path in _files) {
    test('$path tells Android-emulator users to use 10.0.2.2', () {
      final text = File(path).readAsStringSync();

      expect(text, contains('http://10.0.2.2:'));
      expect(
        RegExp('Android emulator', caseSensitive: false).hasMatch(text),
        isTrue,
      );
      expect(text, contains('iOS Simulator'));
    });
  }
}
