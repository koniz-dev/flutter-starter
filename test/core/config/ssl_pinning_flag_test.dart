// ENABLE_SSL_PINNING was read as false for any value but true/1/yes/on, so a
// typo ("ture", "enabled") or a stray blank turned pinning off in a staging or
// production build without a word. Only the on and off spellings count now;
// anything else keeps the environment's default and is reported.
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

  Future<void> loadEnv(List<String> lines) async {
    final name = 'env_flag_${loads++}';
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

  for (final environment in ['staging', 'production']) {
    group(environment, () {
      for (final value in ['enabled', 'ture', '" "']) {
        test(
          'ENABLE_SSL_PINNING=$value keeps pinning on and is reported',
          () async {
            await loadEnv([
              'ENVIRONMENT=$environment',
              'API_SSL_FINGERPRINTS=$_fingerprint',
              'ENABLE_SSL_PINNING=$value',
            ]);

            expect(AppConfig.enableSslPinning, isTrue);
            expect(AppConfig.sslPinningEffective, isTrue);
            expect(AppConfig.sslPinningFlagUnrecognised, isTrue);
          },
        );
      }

      for (final value in ['False ', 'OFF', '0', 'no']) {
        test('ENABLE_SSL_PINNING="$value" is an explicit opt-out', () async {
          await loadEnv([
            'ENVIRONMENT=$environment',
            'API_SSL_FINGERPRINTS=$_fingerprint',
            'ENABLE_SSL_PINNING="$value"',
          ]);

          expect(AppConfig.enableSslPinning, isFalse);
          expect(AppConfig.sslPinningFlagUnrecognised, isFalse);
        });
      }

      test('an unset ENABLE_SSL_PINNING is not reported', () async {
        await loadEnv([
          'ENVIRONMENT=$environment',
          'API_SSL_FINGERPRINTS=$_fingerprint',
        ]);

        expect(AppConfig.enableSslPinning, isTrue);
        expect(AppConfig.sslPinningFlagUnrecognised, isFalse);
      });
    });
  }
}
