// A staging or production release refuses a BASE_URL that is not https. Only
// the scheme is read, so the edge cases are which strings parse to which
// scheme. Values are fed through a `.env` asset, as in
// development_pinning_test.dart, so one run can see several.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/config/env_config.dart';
import 'package:flutter_test/flutter_test.dart';

const _assetChannel = 'flutter/assets';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var loads = 0;

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

  const refused = {
    'http://api.example.com',
    'http://10.0.2.2:3000',
    'api.example.com',
    '/api',
    'localhost:3000',
  };
  const accepted = {'https://api.example.com', 'HTTPS://api.example.com'};

  for (final environment in ['staging', 'production']) {
    group('a $environment release', () {
      for (final url in refused) {
        test('refuses $url', () async {
          await loadEnv(['ENVIRONMENT=$environment', 'BASE_URL=$url']);

          expect(AppConfig.releaseWithoutHttps(releaseMode: true), isTrue);
          expect(
            AppConfig.releaseWithoutHttps(),
            isFalse,
            reason: 'a debug build',
          );
        });
      }
      for (final url in accepted) {
        test('accepts $url', () async {
          await loadEnv(['ENVIRONMENT=$environment', 'BASE_URL=$url']);

          expect(AppConfig.releaseWithoutHttps(releaseMode: true), isFalse);
        });
      }
    });
  }

  test("a development release is not this check's concern", () async {
    await loadEnv([
      'ENVIRONMENT=development',
      'BASE_URL=http://localhost:3000',
    ]);

    expect(AppConfig.releaseWithoutHttps(releaseMode: true), isFalse);
  });
}
