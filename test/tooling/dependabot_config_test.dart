// Dependabot proposes pub and GitHub Actions updates weekly, grouping minor and
// patch bumps so the PR count stays low. `patrol` is excluded: its version must
// match the `patrol_cli` pinned in e2e-android.yml, so a lone bump would make
// the E2E job abort before running a test.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final config =
      loadYaml(File('.github/dependabot.yml').readAsStringSync()) as YamlMap;
  final updates = (config['updates'] as YamlList).cast<YamlMap>();

  YamlMap ecosystem(String name) => updates.singleWhere(
    (u) => u['package-ecosystem'] == name,
    orElse: () => fail('dependabot.yml has no $name entry'),
  );

  test('uses the v2 config format', () {
    expect(config['version'], 2);
  });

  for (final name in const ['pub', 'github-actions']) {
    test('$name: weekly, minor and patch grouped into one PR', () {
      final entry = ecosystem(name);
      expect(entry['directory'], '/');
      expect((entry['schedule'] as YamlMap)['interval'], 'weekly');

      final groups = (entry['groups'] as YamlMap).values.cast<YamlMap>();
      expect(
        groups.map((g) => (g['update-types'] as YamlList).toList()),
        contains(unorderedEquals(['minor', 'patch'])),
      );
    });

    test('$name: commit messages pass the Conventional Commits hook', () {
      final prefix =
          (ecosystem(name)['commit-message'] as YamlMap)['prefix'] as String;
      expect(prefix, matches(RegExp(r'^(chore|ci|build)(\([a-z-]+\))?$')));
    });
  }

  test('patrol is not bumped apart from the pinned patrol_cli', () {
    final ignored = (ecosystem('pub')['ignore'] as YamlList)
        .cast<YamlMap>()
        .map((i) => i['dependency-name']);
    expect(ignored, contains('patrol'));

    // The pin the exclusion protects is still there to protect.
    final e2e = File('.github/workflows/e2e-android.yml').readAsStringSync();
    expect(e2e, contains(RegExp(r'patrol_cli \d+\.\d+\.\d+')));
  });
}
