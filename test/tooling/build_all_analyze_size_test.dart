// scripts/ci/build_all.sh --analyze-size must report what it built, and build
// only the configured app (koniz-dev/flutter-starter#335).
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

/// Runs build_all.sh for [environment] with --analyze-size in a scratch
/// directory; returns the script's output and every stub flutter call.
Future<({String output, List<String> calls})> _run(String environment) async {
  final dir = Directory.systemTemp.createTempSync('build_all_');
  addTearDown(() => dir.deleteSync(recursive: true));
  final bin = Directory('${dir.path}/bin')..createSync();
  for (final (name, body) in [('flutter', _stubFlutter), ('dart', _stubDart)]) {
    final file = File('${bin.path}/$name')..writeAsStringSync(body);
    Process.runSync('chmod', ['+x', file.path]);
  }
  Directory('${dir.path}/scripts/ci').createSync(recursive: true);
  File(
    'scripts/ci/build_all.sh',
  ).copySync('${dir.path}/scripts/ci/build_all.sh');
  final log = '${dir.path}/flutter.log';

  final result = await Process.run(
    'bash',
    ['scripts/ci/build_all.sh', environment, '--analyze-size'],
    workingDirectory: dir.path,
    environment: {
      'PATH': '${bin.path}:${Platform.environment['PATH']}',
      'STUB_LOG': log,
      // Linux runners: skip the iOS branch, which only runs on macOS.
      'OSTYPE': 'linux-gnu',
    },
  );
  expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  return (
    output: '${result.stdout}',
    calls: File(log).readAsLinesSync(),
  );
}

void main() {
  test('criterion 1: production --analyze-size reports the AAB size', () async {
    final run = await _run('production');

    expect(run.output, contains('App Bundle Size:'));
    expect(run.output, isNot(contains('No Android artifact')));
  });

  test(
    'a development run reports both the APK and the comparison bundle',
    () async {
      final run = await _run('development');

      expect(run.output, contains('APK Size:'));
      expect(run.output, contains('App Bundle Size:'));
    },
  );

  for (final environment in ['production', 'staging', 'development']) {
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

  test(
    'criterion 3: the script no longer claims an ABI split it never does',
    () {
      final script = File('scripts/ci/build_all.sh').readAsStringSync();

      expect(script, isNot(contains('already done')));
      expect(script, contains('--split-per-abi'));
    },
  );
}
