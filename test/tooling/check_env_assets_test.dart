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

  group('every spelling of an env file', () {
    const envNames = [
      'production.env',
      'app_config.env',
      'prod.ENV',
      '.env-staging',
      '.env_prod',
      '.envrc',
      '.envrc.local',
    ];

    test('secretAssetReason flags each, and not near misses', () {
      for (final name in envNames) {
        expect(secretAssetReason(name), 'environment file', reason: name);
      }
      for (final name in [
        '.env.example',
        'environment.dart',
        'my.envelope',
        'dotenv.md',
        'env.json',
      ]) {
        expect(secretAssetReason(name), isNull, reason: name);
      }
    });

    test('an acknowledgement naming a new-style file covers it', () {
      final root = Directory.systemTemp.createTempSync('check_env_names_');
      addTearDown(() => root.deleteSync(recursive: true));
      for (final name in ['production.env', '.envrc']) {
        File('${root.path}/assets/config/$name')
          ..createSync(recursive: true)
          ..writeAsStringSync('PUBLIC=1\n');
      }
      const pubspec = '''
flutter:
  assets:
    - assets/config/ # env-asset-ack: production.env, .envrc - public values
''';

      final findings = findBundledDirectorySecrets(
        pubspec,
        projectRoot: root.path,
      );

      expect(findings, hasLength(2));
      expect(findings.every((f) => f.acknowledged), isTrue);
    });

    for (final name in envNames) {
      test('$name named in the asset list is flagged', () {
        final pubspec =
            '''
flutter:
  assets:
    - .env.example
    - assets/$name
''';

        final findings = findDeclaredSecretAssets(pubspec);

        expect(findings, hasLength(1));
        expect(findings.single.entry, 'assets/$name');
      });

      test('$name inside a declared directory is flagged', () {
        final root = Directory.systemTemp.createTempSync('check_env_names_');
        addTearDown(() => root.deleteSync(recursive: true));
        File('${root.path}/assets/config/$name')
          ..createSync(recursive: true)
          ..writeAsStringSync('API_KEY=live-secret\n');
        const pubspec = '''
flutter:
  assets:
    - assets/config/
''';

        final findings = findBundledDirectorySecrets(
          pubspec,
          projectRoot: root.path,
        );

        expect(findings, hasLength(1), reason: name);
        expect(findings.single.acknowledged, isFalse);
      });
    }
  });

  group('parseAcknowledgedNames', () {
    // The grammar is the contract a reviewer reads a comment against, so every
    // clause of it gets a case. It used to be a
    // raw `contains` against free-form prose.
    test('returns nothing when there is no marker', () {
      expect(parseAcknowledgedNames(''), isEmpty);
      expect(parseAcknowledgedNames('# just a comment'), isEmpty);
    });

    test('takes the leading comma-separated run of bare file names', () {
      expect(parseAcknowledgedNames('# $ackMarker .env.web'), <String>[
        '.env.web',
      ]);
      expect(
        parseAcknowledgedNames('# $ackMarker .env.web, app_config.env'),
        <String>['.env.web', 'app_config.env'],
      );
    });

    test('stops at the first comma segment that is not a file name', () {
      // The documented form: names, then prose, separated by a comma.
      expect(
        parseAcknowledgedNames(
          '# $ackMarker .env.example, publishable placeholders only',
        ),
        <String>['.env.example'],
      );
      // A one-word segment is prose too, because it has no dot and so could
      // never be a file this guard can flag.
      expect(
        parseAcknowledgedNames('# $ackMarker .env.web, reviewed'),
        <String>['.env.web'],
      );
    });

    test('allows trailing prose after a semicolon or a dash', () {
      const separators = <String>[';', ' - ', ' -- ', ' \u2014', ' \u2013'];
      for (final separator in separators) {
        expect(
          parseAcknowledgedNames(
            '# $ackMarker .env.web$separator publishable values only',
          ),
          <String>['.env.web'],
          reason: 'separator "$separator" should end the name list',
        );
      }
    });

    test('reads a comment that opens with prose as naming nothing', () {
      // Fails closed: a malformed acknowledgement covers no file at all,
      // rather than every file whose name the prose happens to contain.
      expect(
        parseAcknowledgedNames(
          '# $ackMarker .env.web only; there is no .env here',
        ),
        isEmpty,
      );
      expect(
        parseAcknowledgedNames(
          '# $ackMarker reviewed, no .env or key material in here',
        ),
        isEmpty,
      );
      expect(parseAcknowledgedNames('# $ackMarker'), isEmpty);
    });

    test('does not accept a path, only a bare file name', () {
      expect(
        parseAcknowledgedNames('# $ackMarker assets/config/.env.web'),
        isEmpty,
      );
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
        // guard once did: it reads the list,
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

    test('an ack naming .env.example does not also cover a real .env', () {
      // The whole bug in one case. Every env
      // file name is a prefix of a longer one, so the old substring test read
      // this truthful comment about .env.example as covering .env as well: the
      // guard exited 0 and a live secrets file shipped in the release APK, the
      // release IPA and the web build.
      final pubspec = fixture(
        {'.env.example': 'API_KEY=\n', '.env': 'API_KEY=supersecret\n'},
        comment:
            ' # env-asset-ack: .env.example, publishable placeholders only',
      );

      final findings = findBundledDirectorySecrets(
        pubspec,
        projectRoot: root.path,
      );

      expect(
        findings.map((f) => f.path),
        <String>['assets/config/.env'],
        reason: '.env.example is the one env file that is safe to ship',
      );
      expect(
        findings.single.acknowledged,
        isFalse,
        reason: 'the comment names .env.example, not .env',
      );
    });

    test('an ack naming several files covers each of them', () {
      final pubspec = fixture(
        {'.env.web': '', '.env.staging': ''},
        comment:
            ' # env-asset-ack: .env.web, .env.staging, publishable values only',
      );

      final findings = findBundledDirectorySecrets(
        pubspec,
        projectRoot: root.path,
      );

      expect(findings, hasLength(2));
      expect(findings.every((f) => f.acknowledged), isTrue);
      expect(
        findStaleAcknowledgements(pubspec, projectRoot: root.path),
        isEmpty,
      );
    });

    test('an ack with prose after a dash still names its file', () {
      final pubspec = fixture(
        {'.env.web': ''},
        comment: ' # env-asset-ack: .env.web - publishable values only',
      );

      final findings = findBundledDirectorySecrets(
        pubspec,
        projectRoot: root.path,
      );

      expect(findings.single.acknowledged, isTrue);
    });

    test('prose that merely mentions a file does not acknowledge it', () {
      // The denial case: the comment says there is no .env, and there is one.
      // Under a substring test the denial acknowledged the file it denied.
      final pubspec = fixture(
        {'.env.web': '', '.env': 'DB_PASSWORD=live\n'},
        comment: ' # env-asset-ack: .env.web only; there is no .env here',
      );

      final findings = findBundledDirectorySecrets(
        pubspec,
        projectRoot: root.path,
      );

      expect(
        findings.where((f) => !f.acknowledged).map((f) => f.path),
        <String>['assets/config/.env', 'assets/config/.env.web'],
        reason: 'the name list is empty, so the comment covers nothing',
      );
    });

    test('matches the acknowledged name case-insensitively', () {
      final pubspec = fixture(
        {'GoogleService-Info.plist': ''},
        comment:
            ' # env-asset-ack: googleservice-info.plist, placeholders only',
      );

      final findings = findBundledDirectorySecrets(
        pubspec,
        projectRoot: root.path,
      );

      expect(findings.single.acknowledged, isTrue);
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

  group('findStaleAcknowledgements', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('check_env_assets_stale_');
    });

    tearDown(() {
      root.deleteSync(recursive: true);
    });

    String fixture(Map<String, String> files, {String comment = ''}) {
      final dir = Directory('${root.path}/assets/config')
        ..createSync(recursive: true);
      files.forEach((name, contents) {
        File('${dir.path}/$name').writeAsStringSync(contents);
      });
      return '''
flutter:
  assets:
    - assets/config/$comment
''';
    }

    test('reports a name no file in the directory matches', () {
      final pubspec = fixture(
        {'.gitkeep': ''},
        comment: ' # env-asset-ack: .env.web, publishable values only',
      );

      final stale = findStaleAcknowledgements(pubspec, projectRoot: root.path);

      expect(stale.map((s) => s.name), <String>['.env.web']);
      expect(stale.single.entry, 'assets/config/');
      expect(stale.single.line, 3);
      expect(
        findBundledDirectorySecrets(pubspec, projectRoot: root.path),
        isEmpty,
        reason: 'a stale name is a note, not a bundled secret',
      );
    });

    test('says nothing when the acknowledged file is there', () {
      final pubspec = fixture(
        {'.env.web': ''},
        comment: ' # env-asset-ack: .env.web, publishable values only',
      );

      expect(
        findStaleAcknowledgements(pubspec, projectRoot: root.path),
        isEmpty,
      );
    });

    test('treats every name on a missing directory as stale', () {
      const pubspec = '''
flutter:
  assets:
    - assets/missing/ # env-asset-ack: .env.web, app.env - publishable
''';

      expect(
        findStaleAcknowledgements(
          pubspec,
          projectRoot: root.path,
        ).map((s) => s.name),
        <String>['.env.web', 'app.env'],
      );
    });

    test('ignores a file entry, whose ack names nothing by design', () {
      const pubspec = '''
flutter:
  assets:
    - .env # env-asset-ack: web build, contains no secrets
''';

      expect(
        findStaleAcknowledgements(pubspec, projectRoot: root.path),
        isEmpty,
      );
    });
  });

  group('every asset spelling Flutter accepts', () {
    // The guard used to read only block-style
    // `- <path>` lines, so each pubspec below exited 0 while
    // `flutter build bundle` copied the `.env` into build/flutter_assets/.
    // These drive `run`, which is `main` minus the process exit.
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('check_env_assets_330_');
    });

    tearDown(() {
      root.deleteSync(recursive: true);
    });

    /// Writes [pubspec] and every one of [files] (path -> contents) under the
    /// scratch root, runs the check on it and returns the exit code, with the
    /// report captured in [stderrOf].
    final stderrOf = StringBuffer();
    int check(String pubspec, {Map<String, String> files = const {}}) {
      stderrOf.clear();
      files.forEach((path, contents) {
        File('${root.path}/$path')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(contents);
      });
      final file = File('${root.path}/pubspec.yaml')
        ..writeAsStringSync(pubspec);
      return run(<String>[file.path], out: StringBuffer(), err: stderrOf);
    }

    const secret = {'.env': 'SECRET=1\n'};

    // The advice used to tell web adopters
    // there was no dart-define path, steering them away from the fix.
    test('criterion 2: the failure advice does not claim web lacks '
        'dart-defines', () {
      expect(check('flutter:\n  assets:\n    - .env\n', files: secret), 1);
      final report = stderrOf.toString();

      expect(report, contains('--dart-define-from-file'));
      expect(report, contains('web'));
      expect(report, isNot(contains('no dart-define path')));
      expect(report, isNot(contains('kIsWeb')));
    });

    test('a map-form `- path: .env` entry fails the check', () {
      const pubspec = '''
flutter:
  assets:
    - .env.example
    - path: .env
''';

      expect(check(pubspec, files: secret), 1);
      expect(stderrOf.toString(), contains('pubspec.yaml:4  - .env'));
    });

    test('a map-form directory with a .env inside fails the check', () {
      const pubspec = '''
flutter:
  assets:
    - path: assets/config/
''';

      expect(check(pubspec, files: {'assets/config/.env': 'SECRET=1\n'}), 1);
      expect(
        stderrOf.toString(),
        contains('assets/config/.env (via "assets/config/")'),
      );
    });

    test('a flow-style `assets: [.env]` list fails the check', () {
      expect(check('flutter:\n  assets: [.env]\n', files: secret), 1);
      expect(
        check('flutter:\n  assets: [.env.example, .env]\n', files: secret),
        1,
      );
    });

    test(
      'a map-form entry whose `path:` is not its first key still counts',
      () {
        const pubspec = '''
flutter:
  assets:
    - flavors: [web]
      path: .env
''';

        expect(check(pubspec, files: secret), 1);
        expect(stderrOf.toString(), contains('pubspec.yaml:4  - .env'));
      },
    );

    test('a deferred component asset list is checked too', () {
      const pubspec = '''
flutter:
  deferred-components:
    - name: box
      assets:
        - .env
''';

      expect(check(pubspec, files: secret), 1);
    });

    test('the acknowledgement works on a map-form `path:` line', () {
      const pubspec = '''
flutter:
  assets:
    - path: .env # env-asset-ack: web build, contains no secrets
      flavors: [web]
''';

      expect(check(pubspec, files: secret), 0);
      final finding = findDeclaredSecretAssets(pubspec).single;
      expect(finding.entry, '.env');
      expect(finding.acknowledged, isTrue);
    });

    test('the acknowledgement on a map-form directory names its file', () {
      const pubspec = '''
flutter:
  assets:
    - path: assets/config/ # env-asset-ack: .env.web - publishable only
''';

      expect(check(pubspec, files: {'assets/config/.env.web': ''}), 0);
      expect(
        check(
          pubspec,
          files: {'assets/config/.env.web': '', 'assets/config/.env': ''},
        ),
        1,
        reason: 'the comment names .env.web, not .env',
      );
    });

    test(
      'an acknowledgement on the wrong line of a map entry covers nothing',
      () {
        const pubspec = '''
flutter:
  assets:
    - path: .env
      flavors: [web] # env-asset-ack: web build, contains no secrets
''';

        expect(check(pubspec, files: secret), 1);
      },
    );

    test('one comment on a flow list does not cover every file in it', () {
      // A file entry alone on its line acknowledges itself. In a flow list
      // the comment is shared, so it has to name each file it covers.
      expect(
        check(
          'flutter:\n'
          '  assets: [.env.example, .env] # env-asset-ack: web build\n',
          files: secret,
        ),
        1,
      );
      expect(
        check(
          'flutter:\n'
          '  assets: [.env.example, .env] # env-asset-ack: .env - web build\n',
          files: secret,
        ),
        0,
      );
    });

    test('a quoted path holding a `#` does not open a comment', () {
      const pubspec = '''
flutter:
  assets:
    - "notes #env-asset-ack: x.txt"
    - .env
''';

      final declarations = parseAssetDeclarations(pubspec);

      expect(declarations.first.path, 'notes #env-asset-ack: x.txt');
      expect(declarations.first.comment, isEmpty);
      expect(check(pubspec, files: secret), 1);
    });

    group('fails closed on what it cannot read', () {
      const unreadable = <String, String>{
        'invalid YAML': 'flutter:\n  assets:\n    - .env\n   bad: [\n',
        'assets is a string': 'flutter:\n  assets: .env\n',
        'map entry without path': 'flutter:\n  assets:\n    - flavors: [x]\n',
        'entry is not a string': 'flutter:\n  assets:\n    - 42\n',
        'empty entry': 'flutter:\n  assets:\n    -\n',
        'flutter is a list': 'flutter:\n  - assets\n',
      };

      unreadable.forEach((name, pubspec) {
        test('$name: exit 2, never 0', () {
          expect(
            () => parseAssetDeclarations(pubspec),
            throwsA(isA<AssetListFormatException>()),
          );
          expect(check(pubspec, files: secret), 2);
          expect(stderrOf.toString(), contains('cannot read the asset list'));
        });
      });

      test('a pubspec with no flutter section is still clean', () {
        expect(check('name: plain_dart\n'), 0);
        expect(check(''), 0);
      });
    });

    test('`main` itself exits 1 on a map-form .env', () async {
      // `run` is what `main` returns; this pins the wiring between the two
      // through the same command CI and the deploy workflows use.
      File('${root.path}/.env').writeAsStringSync('SECRET=1\n');
      final pubspec = File('${root.path}/pubspec.yaml')
        ..writeAsStringSync('flutter:\n  assets:\n    - path: .env\n');

      final result = await Process.run('dart', <String>[
        'run',
        'tool/check_env_assets.dart',
        pubspec.path,
      ]);

      expect(result.exitCode, 1, reason: '${result.stderr}');
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
          'the web build. Use --dart-define-from-file on every target, and '
          'keep secrets on the server. See docs/guides/configuration.md.',
    );
  });
}
