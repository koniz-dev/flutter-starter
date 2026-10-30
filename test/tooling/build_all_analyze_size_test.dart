// scripts/ci/build_all.sh --analyze-size must report what it built, and build
// only the configured app.
//
// Production builds only an App Bundle, but the analysis looked only for an
// APK, so it reported nothing; the comparison bundle was built without the
// environment's --dart-define values; and the advice claimed an ABI split
// that nothing performs. These run the real script against a stub `flutter`
// (and `dart`) on PATH that logs every call and writes the artifact a real
// build would.

@TestOn('!windows')
// The stub scripts must start with their shebang, so no leading newline.
// ignore_for_file: leading_newlines_in_multiline_strings
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _stubFlutter = r'''#!/usr/bin/env bash
echo "flutter $*" >> "$STUB_LOG"
case "$1 $2" in
  "build appbundle")
    mkdir -p build/app/outputs/bundle/release
    head -c 4096 /dev/zero > build/app/outputs/bundle/release/app-release.aab ;;
  "build apk")
    mkdir -p build/app/outputs/flutter-apk
    head -c 8192 /dev/zero > build/app/outputs/flutter-apk/app-release.apk ;;
  "pub deps") echo "├── dio 5.0.0" ;;
esac
exit 0
''';

const _stubDart = '''#!/usr/bin/env bash
exit 0
''';

/// A stand-in fingerprint list, so a staging or production run is not
/// refused for missing pinning.
const _fingerprints = 'AA:BB,CC:DD';

/// Runs build_all.sh for [environment] with --analyze-size in a scratch
/// directory; returns the script's exit code, its output and every stub
/// flutter call. [env] replaces the default pinning variables.
Future<({int exitCode, String output, List<String> calls})> _run(
  String environment, {
  Map<String, String> env = const {'API_SSL_FINGERPRINTS': _fingerprints},
  bool expectSuccess = true,
}) async {
  final dir = Directory.systemTemp.createTempSync('build_all_');
  addTearDown(() => dir.deleteSync(recursive: true));
  final bin = Directory('${dir.path}/bin')..createSync();
  for (final (name, body) in [('flutter', _stubFlutter), ('dart', _stubDart)]) {
    final file = File('${bin.path}/$name')..writeAsStringSync(body);
    Process.runSync('chmod', ['+x', file.path]);
  }
  Directory('${dir.path}/scripts/ci').createSync(recursive: true);
  for (final script in ['build_all.sh', 'ssl_pinning_defines.sh']) {
    File('scripts/ci/$script').copySync('${dir.path}/scripts/ci/$script');
  }
  final log = File('${dir.path}/flutter.log');

  final result = await Process.run(
    'bash',
    ['scripts/ci/build_all.sh', environment, '--analyze-size'],
    workingDirectory: dir.path,
    environment: {
      'PATH': '${bin.path}:${Platform.environment['PATH']}',
      'STUB_LOG': log.path,
      // Linux runners: skip the iOS branch, which only runs on macOS.
      'OSTYPE': 'linux-gnu',
      // Not inherited from the machine running the tests.
      'API_SSL_FINGERPRINTS': '',
      'ENABLE_SSL_PINNING': '',
      ...env,
    },
  );
  if (expectSuccess) {
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  }
  return (
    exitCode: result.exitCode,
    output: '${result.stdout}${result.stderr}',
    calls: log.existsSync() ? log.readAsLinesSync() : <String>[],
  );
}

void main() {
  test('criterion 1: production --analyze-size reports the AAB size', () async {
    final run = await _run('production');

    expect(run.output, contains('App Bundle Size:'));
    expect(run.output, isNot(contains('No Android artifact')));
  });

  test(
    'a staging run reports both the APK and the comparison bundle',
    () async {
      final run = await _run('staging');

      expect(run.output, contains('APK Size:'));
      expect(run.output, contains('App Bundle Size:'));
    },
  );

  for (final environment in ['production', 'staging']) {
    test('criterion 2 ($environment): every flutter build carries the '
        'ENVIRONMENT and BASE_URL defines', () async {
      final run = await _run(environment);
      final builds = run.calls.where((c) => c.startsWith('flutter build '));

      expect(builds, isNotEmpty);
      for (final call in builds) {
        expect(call, contains('--dart-define=ENVIRONMENT=$environment'));
        expect(call, contains('--dart-define=BASE_URL='));
      }
    });
  }

  // Pinning is on in staging and production, and a release built with
  // pinning on and no fingerprints refuses to start.
  for (final environment in ['production', 'staging']) {
    test('$environment without API_SSL_FINGERPRINTS is refused before '
        'anything is built', () async {
      final run = await _run(environment, env: const {}, expectSuccess: false);

      expect(run.exitCode, isNot(0));
      expect(run.output, contains('API_SSL_FINGERPRINTS is empty'));
      expect(run.calls, isEmpty, reason: 'flutter was never called');
    });

    test(
      '$environment: every flutter build carries the fingerprints',
      () async {
        final run = await _run(environment);
        final builds = run.calls.where((c) => c.startsWith('flutter build '));

        expect(builds, isNotEmpty);
        for (final call in builds) {
          expect(
            call,
            contains('--dart-define=API_SSL_FINGERPRINTS=$_fingerprints'),
          );
        }
      },
    );
  }

  test('ENABLE_SSL_PINNING=false builds without fingerprints and passes the '
      'opt-out to every build', () async {
    final run = await _run(
      'production',
      env: const {'ENABLE_SSL_PINNING': 'false'},
    );
    final builds = run.calls.where((c) => c.startsWith('flutter build '));

    expect(builds, isNotEmpty);
    for (final call in builds) {
      expect(call, contains('--dart-define=ENABLE_SSL_PINNING=false'));
      expect(call, isNot(contains('API_SSL_FINGERPRINTS')));
    }
  });

  test(
    'ENABLE_SSL_PINNING=true without fingerprints is still refused',
    () async {
      final run = await _run(
        'production',
        env: const {'ENABLE_SSL_PINNING': 'true'},
        expectSuccess: false,
      );

      expect(run.exitCode, isNot(0));
      expect(run.calls, isEmpty);
    },
  );

  // Every artifact it builds is a release build, and a release build
  // configured as development refuses to start.
  test('development is refused before anything is built', () async {
    final dir = Directory.systemTemp.createTempSync('build_all_dev_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final bin = Directory('${dir.path}/bin')..createSync();
    final stub = File('${bin.path}/flutter')..writeAsStringSync(_stubFlutter);
    Process.runSync('chmod', ['+x', stub.path]);
    Directory('${dir.path}/scripts/ci').createSync(recursive: true);
    for (final script in ['build_all.sh', 'ssl_pinning_defines.sh']) {
      File('scripts/ci/$script').copySync('${dir.path}/scripts/ci/$script');
    }
    final log = File('${dir.path}/flutter.log');

    final result = await Process.run(
      'bash',
      ['scripts/ci/build_all.sh', 'development'],
      workingDirectory: dir.path,
      environment: {
        'PATH': '${bin.path}:${Platform.environment['PATH']}',
        'STUB_LOG': log.path,
        'OSTYPE': 'linux-gnu',
      },
    );

    expect(result.exitCode, isNot(0));
    expect('${result.stdout}', contains('refuses to start'));
    expect('${result.stdout}', contains('flutter run'));
    expect(log.existsSync(), isFalse, reason: 'flutter was never called');
  });

  test(
    'criterion 3: the script no longer claims an ABI split it never does',
    () {
      final script = File('scripts/ci/build_all.sh').readAsStringSync();

      expect(script, isNot(contains('already done')));
      expect(script, contains('--split-per-abi'));
    },
  );
}
