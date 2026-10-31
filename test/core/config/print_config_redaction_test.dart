// AppConfig.printConfig, which main() calls in debug builds, printed BASE_URL
// raw, so userinfo or a token in its query reached the console and any log
// capture. It now prints it through ApiLoggingInterceptor.redactUrl, as the
// startup refusal of a non-https BASE_URL does.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/config/env_config.dart';
import 'package:flutter_test/flutter_test.dart';

const _assetChannel = 'flutter/assets';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> loadEnv(String name, String contents) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(_assetChannel, (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key != name) return null;
          return ByteData.view(
            Uint8List.fromList(utf8.encode(contents)).buffer,
          );
        });
    await EnvConfig.load(fileName: name);
  }

  tearDown(() async {
    await loadEnv('env_reset', 'ENVIRONMENT=development\n');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(_assetChannel, null);
  });

  test(
    'printConfig shows BASE_URL without its userinfo or query secret',
    () async {
      await loadEnv(
        'env_secret_base_url',
        'ENVIRONMENT=development\n'
            'BASE_URL=https://user:s3cr3t@api.example.com/v1?token=T0KEN\n',
      );
      final printed = <String>[];
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
      try {
        AppConfig.printConfig();
      } finally {
        debugPrint = original;
      }

      final baseUrl = printed.singleWhere((l) => l.contains('Base URL'));
      expect(baseUrl, isNot(contains('s3cr3t')));
      expect(baseUrl, isNot(contains('T0KEN')));
      expect(baseUrl, contains('api.example.com'));
    },
  );
}
