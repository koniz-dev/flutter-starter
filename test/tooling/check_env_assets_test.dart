import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Relative import: tool/ is not part of the published library, so there is no
// package: URI for it. test/ and tool/ are both outside lib/, which is what
// avoid_relative_lib_imports cares about.
import '../../tool/check_env_assets.dart';

void main() {
  group('findBundledEnvAssets', () {
    test('flags a bare .env in the flutter asset list', () {
      const pubspec = '''
name: flutter_starter

flutter:
  uses-material-design: true
  assets:
    - .env.example
    - .env
''';

      final findings = findBundledEnvAssets(pubspec);

      expect(findings, hasLength(1));
      expect(findings.single.entry, '.env');
      expect(findings.single.line, 7);
      expect(findings.single.acknowledged, isFalse);
    });

    test('does not flag .env.example', () {
      const pubspec = '''
flutter:
  assets:
    - .env.example
''';

      expect(findBundledEnvAssets(pubspec), isEmpty);
    });

    test('flags any other env variant, including per-environment files', () {
      const pubspec = '''
flutter:
  assets:
    - .env.production
    - config/.env.staging
''';

      final findings = findBundledEnvAssets(pubspec);

      expect(
        findings.map((f) => f.entry),
        <String>['.env.production', 'config/.env.staging'],
      );
      expect(findings.every((f) => !f.acknowledged), isTrue);
    });

    test('treats an inline acknowledgement as reviewed, not as a failure', () {
      const pubspec = '''
flutter:
  assets:
    - .env # env-asset-ack: web build, contains no secrets
''';

      final findings = findBundledEnvAssets(pubspec);

      expect(findings, hasLength(1));
      expect(findings.single.entry, '.env');
      expect(findings.single.acknowledged, isTrue);
    });

    test('ignores a commented-out example asset list', () {
      const pubspec = '''
flutter:
  # assets:
  #   - .env
  uses-material-design: true
''';

      expect(findBundledEnvAssets(pubspec), isEmpty);
    });

    test('ignores an assets list belonging to another top-level key', () {
      const pubspec = '''
some_other_tool:
  assets:
    - .env

flutter:
  uses-material-design: true
''';

      expect(findBundledEnvAssets(pubspec), isEmpty);
    });

    test('stops at the end of the asset list', () {
      const pubspec = '''
flutter:
  assets:
    - .env.example
  fonts:
    - family: Schyler
      fonts:
        - asset: fonts/Schyler-Regular.ttf
''';

      expect(findBundledEnvAssets(pubspec), isEmpty);
    });
  });

  test("this repository's pubspec.yaml bundles no secrets file", () {
    // The guard that matters: `flutter test` runs in CI, so a commit that adds
    // `- .env` to the asset list turns the Quality gate red instead of shipping
    // a plaintext secrets file in every release artifact.
    final pubspec = File('pubspec.yaml').readAsStringSync();

    final unacknowledged = findBundledEnvAssets(
      pubspec,
    ).where((f) => !f.acknowledged).toList();

    expect(
      unacknowledged.map((f) => '${f.entry} (line ${f.line})'),
      isEmpty,
      reason:
          'A Flutter asset declaration is not build-mode scoped. Anything '
          'listed under flutter: assets: ships in the release APK, the '
          'release IPA and the web build. Use --dart-define-from-file on '
          'native; on web, keep secrets on the server. See '
          'docs/guides/configuration.md.',
    );
  });
}
