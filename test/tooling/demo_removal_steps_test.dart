// getting-started.md tells an adopter how to remove the offline demo sign-in
// and promises flutter analyze passes afterwards. That holds only while every
// file that uses the demo is one the steps delete or edit; a test that
// imports the demo from anywhere else breaks analyze after the removal.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _guide = 'docs/guides/onboarding/getting-started.md';

/// Paths the steps delete outright, as the guide names them.
const _deleted = [
  'lib/features/auth/demo/',
  'test/features/auth/demo/',
  'test/flutter_test_config.dart',
  'test/acceptance/login_demo_acceptance_test.dart',
];

/// Files the steps edit, by the name the guide uses.
const _edited = {
  'lib/features/auth/di/auth_providers.dart': 'auth_providers.dart',
  'lib/features/auth/presentation/screens/login_screen.dart':
      'login_screen.dart',
};

final _usesDemo = RegExp('DemoAuth|DemoSignInCard|auth/demo');

void main() {
  final guide = File(_guide).readAsStringSync();

  test('the guide names every path it relies on', () {
    for (final path in _deleted) {
      expect(guide, contains('`$path`'), reason: path);
    }
    for (final name in _edited.values) {
      expect(guide, contains('`$name`'), reason: name);
    }
  });

  test('only the files the steps delete or edit use the demo', () {
    final strays = <String>[];
    for (final root in ['lib', 'test', 'integration_test']) {
      for (final entity in Directory(root).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll(r'\', '/');
        if (_deleted.any(path.startsWith) || _edited.containsKey(path)) {
          continue;
        }
        if (path == 'test/tooling/demo_removal_steps_test.dart') continue;
        if (_usesDemo.hasMatch(entity.readAsStringSync())) strays.add(path);
      }
    }
    expect(strays, isEmpty, reason: 'delete or edit these in $_guide too');
  });
}
