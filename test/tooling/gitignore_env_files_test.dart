// .gitignore listed a few .env names, so .env.development, .env.dev,
// .env.prod and .env.test - per-environment inputs that may hold secrets -
// could be committed. Every .env file is ignored now, except the template.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

bool _ignored(String path) =>
    Process.runSync('git', [
      'check-ignore',
      '--no-index',
      '-q',
      path,
    ]).exitCode ==
    0;

void main() {
  test('every .env file is ignored except .env.example', () {
    for (final name in [
      '.env',
      '.env.development',
      '.env.dev',
      '.env.prod',
      '.env.production',
      '.env.staging',
      '.env.test',
      '.env.local',
      '.env.dev.local',
    ]) {
      expect(_ignored(name), isTrue, reason: name);
    }
    expect(_ignored('.env.example'), isFalse);
  });
}
