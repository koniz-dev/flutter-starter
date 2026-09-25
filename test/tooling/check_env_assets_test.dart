import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Relative import: tool/ is not part of the published library, so there is no
// package: URI for it. test/ and tool/ are both outside lib/, which is what
// avoid_relative_lib_imports cares about.
import '../../tool/check_env_assets.dart';

void main() {
  group('findDeclaredSecretAssets', () {
    test('flags a bare .env in the flutter asset list', () {
      const pubspec = '''
name: flutter_starter

flutter:
  uses-material-design: true
  assets:
    - .env.example
    - .env
''';

      final findings = findDeclaredSecretAssets(pubspec);

      expect(findings, hasLength(1));
      expect(findings.single.entry, '.env');
      expect(findings.single.line, 7);
      expect(findings.single.acknowledged, isFalse);
      expect(findings.single.viaDirectory, isFalse);
    });

    test('does not flag .env.example', () {
      const pubspec = '''
flutter:
  assets:
    - .env.example
''';

      expect(findDeclaredSecretAssets(pubspec), isEmpty);
    });

    test('flags any other env variant, including per-environment files', () {
      const pubspec = '''
flutter:
  assets:
    - .env.production
    - config/.env.staging
''';

      final findings = findDeclaredSecretAssets(pubspec);

      expect(
        findings.map((f) => f.entry),
        <String>['.env.production', 'config/.env.staging'],
      );
      expect(findings.every((f) => !f.acknowledged), isTrue);
    });

    test('flags named key material and credential files too', () {
      const pubspec = '''
flutter:
  assets:
    - assets/config/secrets.json
    - assets/keys/upload.keystore
''';

      final findings = findDeclaredSecretAssets(pubspec);

      expect(
        findings.map((f) => f.reason),
        <String>['credential file', 'private key or code-signing material'],
      );
    });

    test('treats an inline acknowledgement as reviewed, not as a failure', () {
      const pubspec = '''
flutter:
  assets:
    - .env # env-asset-ack: web build, contains no secrets
''';

      final findings = findDeclaredSecretAssets(pubspec);

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

      expect(findDeclaredSecretAssets(pubspec), isEmpty);
    });

    test('ignores an assets list belonging to another top-level key', () {
      const pubspec = '''
some_other_tool:
  assets:
    - .env

flutter:
  uses-material-design: true
''';

      expect(findDeclaredSecretAssets(pubspec), isEmpty);
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

      expect(findDeclaredSecretAssets(pubspec), isEmpty);
    });
  });

  group('secretAssetReason', () {
    test('matches env files, key material and credential stores', () {
      expect(secretAssetReason('.env'), 'environment file');
      expect(secretAssetReason('.env.production'), 'environment file');
      expect(secretAssetReason('upload.jks'), isNotNull);
      expect(secretAssetReason('server.PEM'), isNotNull);
      expect(secretAssetReason('secrets.json'), 'credential file');
      expect(secretAssetReason('GoogleService-Info.plist'), 'credential file');
    });

    test('leaves .env.example and ordinary configuration alone', () {
      // The boundary is deliberate: matching `config.json` inside a directory
      // named assets/config/ would fire on legitimate configuration, and a
      // guard that cries wolf gets deleted rather than fixed.
      expect(secretAssetReason('.env.example'), isNull);
      expect(secretAssetReason('config.json'), isNull);
      expect(secretAssetReason('app_config.yaml'), isNull);
      expect(secretAssetReason('logo.png'), isNull);
      // A certificate is public by design; a pinning setup may ship one.
      expect(secretAssetReason('server.crt'), isNull);
      expect(secretAssetReason('root_ca.cer'), isNull);
    });
  });

  group('findBundledDirectorySecrets', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('check_env_assets_');
    });

    tearDown(() {
      root.deleteSync(recursive: true);
    });

    /// Writes [files] under `assets/config/` and returns a pubspec declaring
    /// the directory, with [comment] appended to the directory entry.
    String fixture(Map<String, String> files, {String comment = ''}) {
      final dir = Directory('${root.path}/assets/config')
        ..createSync(recursive: true);
      files.forEach((name, contents) {
        File('${dir.path}/$name').writeAsStringSync(contents);
      });
      return '''
flutter:
  uses-material-design: true
  assets:
    - .env.example
    - assets/config/$comment
''';
    }

    test(
      'catches a .env the asset list never names - the gap this closes',
      () {
        // The counterfactual. findDeclaredSecretAssets is exactly what the
        // guard did before koniz-dev/flutter-starter#138: it reads the list,
        // and the list says nothing about this file. The directory walk is
        // what sees it.
        final pubspec = fixture({
          '.gitkeep': '',
          '.env': 'API_KEY=live-secret\n',
        });

        expect(
          findDeclaredSecretAssets(pubspec),
          isEmpty,
          reason: 'the pubspec diff is empty - nothing names the file',
        );

        final findings = findBundledDirectorySecrets(
          pubspec,
          projectRoot: root.path,
        );

        expect(findings, hasLength(1));
        expect(findings.single.path, 'assets/config/.env');
        expect(findings.single.entry, 'assets/config/');
        expect(findings.single.line, 5);
        expect(findings.single.reason, 'environment file');
        expect(findings.single.acknowledged, isFalse);
        expect(findings.single.viaDirectory, isTrue);
      },
    );

    test('passes on the directories as they ship, holding only .gitkeep', () {
      final pubspec = fixture({'.gitkeep': ''});

      expect(
        findBundledDirectorySecrets(pubspec, projectRoot: root.path),
        isEmpty,
      );
    });

    test('flags key material and credential files, not ordinary config', () {
      final pubspec = fixture({
        'app_config.json': '{}',
        'logo.png': '',
        'upload.p12': '',
        'secrets.json': '{}',
      });

      final findings = findBundledDirectorySecrets(
        pubspec,
        projectRoot: root.path,
      );

      expect(
        findings.map((f) => f.path),
        <String>['assets/config/secrets.json', 'assets/config/upload.p12'],
      );
    });

    test('an acknowledgement naming the file is reviewed, not a failure', () {
      final pubspec = fixture(
        {'.env.web': 'API_URL=https://public\n'},
        comment: ' # env-asset-ack: .env.web, publishable values only',
      );

      final findings = findBundledDirectorySecrets(
        pubspec,
        projectRoot: root.path,
      );

      expect(findings, hasLength(1));
      expect(findings.single.acknowledged, isTrue);
    });

    test('an acknowledgement for one file does not cover another', () {
      // Otherwise a single comment silences the directory forever, which is the
      // failure mode the inline marker exists to avoid.
      final pubspec = fixture(
        {'.env.web': '', '.env.production': 'DB_PASSWORD=live\n'},
        comment: ' # env-asset-ack: .env.web, publishable values only',
      );

      final findings = findBundledDirectorySecrets(
        pubspec,
        projectRoot: root.path,
      );

      expect(findings, hasLength(2));
      expect(
        findings.where((f) => !f.acknowledged).map((f) => f.path),
        <String>['assets/config/.env.production'],
      );
    });

    test('does not report a sub-directory Flutter would not bundle', () {
      // Flutter bundles files directly inside a declared directory and does not
      // recurse; a sub-directory needs its own asset entry, and is then walked
      // in its own right.
      final pubspec = fixture({'.gitkeep': ''});
      Directory('${root.path}/assets/config/private').createSync();
      File('${root.path}/assets/config/private/.env').writeAsStringSync('X=1');

      expect(
        findBundledDirectorySecrets(pubspec, projectRoot: root.path),
        isEmpty,
      );
    });

    test('tolerates a declared directory that does not exist', () {
      const pubspec = '''
flutter:
  assets:
    - assets/missing/
''';

      expect(
        findBundledDirectorySecrets(pubspec, projectRoot: root.path),
        isEmpty,
      );
    });
  });

  test("this repository's pubspec.yaml bundles no secrets file", () {
    // The guard that matters: `flutter test` runs in CI, so a commit that adds
    // `- .env` to the asset list - or drops one into assets/config/ - turns the
    // Quality gate red instead of shipping a plaintext secrets file in every
    // release artifact. A gitignored file is invisible to CI but not to the
    // same check run locally by scripts/dev/audit_template.sh.
    final pubspec = File('pubspec.yaml').readAsStringSync();

    final unacknowledged = <BundledSecretAsset>[
      ...findDeclaredSecretAssets(pubspec),
      ...findBundledDirectorySecrets(pubspec, projectRoot: '.'),
    ].where((f) => !f.acknowledged).toList();

    expect(
      unacknowledged.map((f) => '${f.path} (line ${f.line})'),
      isEmpty,
      reason:
          'A Flutter asset declaration is not build-mode scoped. Anything '
          'listed under flutter: assets: - including every file inside a '
          'declared directory - ships in the release APK, the release IPA and '
          'the web build. Use --dart-define-from-file on native; on web, keep '
          'secrets on the server. See docs/guides/configuration.md.',
    );
  });
}
