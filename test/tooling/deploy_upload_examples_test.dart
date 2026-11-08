@TestOn('!windows')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String commentedRun(String file, String name) {
  final source = File(file).readAsStringSync();
  final start = source.indexOf('      # - name: $name');
  expect(start, greaterThanOrEqualTo(0));
  final step = source
      .substring(start)
      .split('\n\n')
      .first
      .split('      #   run: |\n')
      .last;
  return step
      .split('\n')
      .where((line) => line.startsWith('      #     '))
      .map((line) => line.substring('      #     '.length))
      .join('\n');
}

void main() {
  test('iOS upload receives private JSON with PEM content', () async {
    final dir = Directory.systemTemp.createTempSync('deliver_key_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final run = commentedRun(
      '.github/workflows/deploy-ios.yml',
      'Setup App Store Connect API Key',
    );
    const key =
        '-----BEGIN PRIVATE KEY-----\n'
        'fake-test-key\n-----END PRIVATE KEY-----\n';
    final result = await Process.run(
      'bash',
      ['-eu', '-c', run],
      environment: {
        'RUNNER_TEMP': dir.path,
        'APP_STORE_CONNECT_KEY_ID': 'test-id',
        'APP_STORE_CONNECT_ISSUER_ID': 'test-issuer',
        'APP_STORE_CONNECT_API_KEY_BASE64':
            '${base64.encode(utf8.encode(key)).substring(0, 20)}\n'
            '${base64.encode(utf8.encode(key)).substring(20)}\n',
      },
    );
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final json = File('${dir.path}/app-store-connect-api.json');
    expect(jsonDecode(json.readAsStringSync()), {
      'key_id': 'test-id',
      'issuer_id': 'test-issuer',
      'key': key,
    });
    expect(json.statSync().mode & 0x1ff, 0x180);
    final upload = commentedRun(
      '.github/workflows/deploy-ios.yml',
      'Upload to App Store Connect',
    );
    expect(
      upload,
      contains(r'--api_key_path "$RUNNER_TEMP/app-store-connect-api.json"'),
    );
    expect(upload, isNot(contains('--api_key_id')));
    expect(upload, isNot(contains('--api_issuer')));
    expect(upload, isNot(contains('.p8')));
  });

  test(
    'Google Play release notes are staged under the locale filename',
    () async {
      final dir = Directory.systemTemp.createTempSync('play_notes_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final source = File(
        '${dir.path}/fastlane/metadata/android/en-US/changelogs/default.txt',
      );
      source.parent.createSync(recursive: true);
      source.writeAsStringSync('Test release notes\n');
      final run = commentedRun(
        '.github/workflows/deploy-android.yml',
        'Stage Google Play release notes',
      );
      final result = await Process.run('bash', [
        '-eu',
        '-c',
        run,
      ], workingDirectory: dir.path);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(
        File('${dir.path}/distribution/whatsnew/whatsnew-en-US')
            .readAsStringSync(),
        source.readAsStringSync(),
      );
      expect(
        File('.github/workflows/deploy-android.yml').readAsStringSync(),
        contains('whatsNewDirectory: distribution/whatsnew'),
      );
    },
  );
}
