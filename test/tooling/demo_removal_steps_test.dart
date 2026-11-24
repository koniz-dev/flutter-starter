// getting-started.md tells an adopter how to remove the offline demo sign-in
// and promises flutter analyze and flutter test pass afterwards. That holds
// only while every file that uses the demo is one the steps delete or edit;
// a test that imports the demo from anywhere else breaks analyze after the
// removal, and an unread hasBackend fails app_config_getters_used_test.
// A link to the section the steps delete fails doc_links_test the same way.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _guide = 'docs/guides/onboarding/getting-started.md';

/// Paths the steps delete outright, as the guide names them.
const _deleted = [
  'lib/features/auth/demo/',
  'test/features/auth/demo/',
  'test/flutter_test_config.dart',
  'test/acceptance/login_demo_acceptance_test.dart',
  'test/core/config/app_config_has_backend_test.dart',
  'test/tooling/demo_removal_steps_test.dart',
];

/// Files the steps edit, by the name the guide uses.
const Map<String, String> _edited = {
  'lib/features/auth/di/auth_providers.dart': 'auth_providers.dart',
  'lib/features/auth/presentation/screens/login_screen.dart':
      'login_screen.dart',
  'lib/core/config/app_config.dart': 'app_config.dart',
  'docs/api/features/auth/providers.md': 'docs/api/features/auth/providers.md',
  'docs/guides/configuration.md': 'docs/guides/configuration.md',
  'README.md': 'README.md',
  // The section itself, which step 3 deletes.
  _guide: _guide,
};

/// The anchor of the section the steps delete.
const _anchor = '#signing-in-before-you-have-a-backend';

/// The terms of the guide's own `git grep`.
final _usesDemo = RegExp(
  'DemoAuth|DemoSignInCard|auth/demo|hasBackend|${_anchor.substring(1)}',
);

/// Tracked files, the existing ones only: a tree the strip tool has run on
/// still lists the files it deleted.
List<String> _trackedFiles(List<String> pathspecs) {
  final result = Process.runSync('git', ['ls-files', ...pathspecs]);
  expect(result.exitCode, 0, reason: '${result.stderr}');
  return [
    for (final path in (result.stdout as String).trim().split('\n'))
      if (path.isNotEmpty && File(path).existsSync()) path,
  ];
}

bool _deletedOrEdited(String path) =>
    _deleted.any(path.startsWith) || _edited.containsKey(path);

void main() {
  final guide = File(_guide).readAsStringSync();

  test('the guide names every path it relies on', () {
    for (final path in _deleted) {
      expect(guide, contains('`$path`'), reason: path);
    }
    for (final name in _edited.values.where((n) => n != _guide)) {
      expect(guide, contains('`$name`'), reason: name);
    }
  });

  test('only the files the steps delete or edit use the demo', () {
    // Tracked files only: CI generates a git-ignored coverage helper that
    // imports every library, the demo included.
    final strays = <String>[];
    for (final path in _trackedFiles([
      'lib',
      'test',
      'integration_test',
      'docs',
      'README.md',
    ])) {
      if (!path.endsWith('.dart') && !path.endsWith('.md')) continue;
      if (_deletedOrEdited(path)) continue;
      if (_usesDemo.hasMatch(File(path).readAsStringSync())) strays.add(path);
    }
    expect(strays, isEmpty, reason: 'delete or edit these in $_guide too');
  });

  test('only the files the steps delete or edit link to the section', () {
    // Every markdown file in the repository, not only the paths the guide's
    // git grep covers: a link from anywhere else dangles once the section
    // is gone.
    final strays = [
      for (final path in _trackedFiles(['*.md']))
        if (!_deletedOrEdited(path) &&
            File(path).readAsStringSync().contains(_anchor))
          path,
    ];
    expect(strays, isEmpty, reason: 'delete or edit these in $_guide too');
  });
}
