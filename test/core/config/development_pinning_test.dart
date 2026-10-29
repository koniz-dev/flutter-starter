// Configured fingerprints are a statement that the backend is pinned. In
// development they used to be ignored unless ENABLE_SSL_PINNING was also set,
// so a release built as development shipped unpinned without a word.
//
// Values are fed through a `.env` asset rather than `--dart-define`, because a
// dart-define is a compile-time constant: one test run could only ever see
// one value.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/config/env_config.dart';
import 'package:flutter_test/flutter_test.dart';

const _assetChannel = 'flutter/assets';
final String _fingerprint = 'a' * 64;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var loads = 0;

  /// Loads a `.env` holding [lines], under a fresh asset name so the asset
  /// bundle's string cache cannot hand back the previous one.
  Future<void> loadEnv(List<String> lines) async {
    final name = 'env_${loads++}';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(_assetChannel, (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key != name) return null;
          final bytes = Uint8List.fromList(
            utf8.encode('${lines.join('\n')}\n'),
          );
          return ByteData.view(bytes.buffer);
        });
    await EnvConfig.load(fileName: name);
    expect(EnvConfig.isInitialized, isTrue, reason: 'the .env must load');
  }

  tearDownAll(() async {
    await loadEnv(['ENVIRONMENT=development']);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(_assetChannel, null);
  });

  group('pinning in development', () {
    test(
      'fingerprints with ENABLE_SSL_PINNING unset enforce pinning',
      () async {
        await loadEnv([
          'ENVIRONMENT=development',
          'API_SSL_FINGERPRINTS=$_fingerprint',
        ]);

        expect(AppConfig.isDevelopment, isTrue);
        expect(AppConfig.enableSslPinning, isTrue);
        expect(AppConfig.sslPinningEffective, isTrue);
        expect(AppConfig.sslPinningMisconfigured, isFalse);
      },
    );

    test('ENABLE_SSL_PINNING=false still turns it off', () async {
      await loadEnv([
        'ENVIRONMENT=development',
        'API_SSL_FINGERPRINTS=$_fingerprint',
        'ENABLE_SSL_PINNING=false',
      ]);

      expect(AppConfig.enableSslPinning, isFalse);
    });

    test('no fingerprints leaves it off, for proxy debugging', () async {
      await loadEnv(['ENVIRONMENT=development']);

      expect(AppConfig.enableSslPinning, isFalse);
      expect(AppConfig.sslPinningMisconfigured, isFalse);
    });
  });

  group('releaseBuiltAsDevelopment', () {
    for (final (environment, release, expected) in [
      ('development', true, true),
      ('development', false, false),
      ('staging', true, false),
      ('production', true, false),
    ]) {
      test(
        'ENVIRONMENT=$environment, releaseMode: $release -> $expected',
        () async {
          await loadEnv(['ENVIRONMENT=$environment']);

          expect(
            AppConfig.releaseBuiltAsDevelopment(releaseMode: release),
            expected,
          );
        },
      );
    }
  });
}
