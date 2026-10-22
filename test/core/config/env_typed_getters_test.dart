// EnvConfig's typed getters must follow the documented priority order -
// .env, then --dart-define, then the default - when a .env is loaded that
// lacks the key.
//
// They used to ask dotenv for the key with `fallback: defaultValue`. dotenv
// returns the fallback instead of throwing when the key is missing, so the
// dart-define was never consulted: `has` was true and `get` was "true", but
// `getBool` was false, and `--dart-define=ENABLE_SSL_PINNING=true` left
// pinning off whenever any .env was bundled.
//
// Run with the defines the define-path tests need:
//   flutter test <this file> \
//     --dart-define=ENABLE_SSL_PINNING=true \
//     --dart-define=API_CONNECT_TIMEOUT=60 \
//     --dart-define=API_TIMEOUT=2.5
// Without them those tests are skipped, and the .env-path tests still run.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/config/dart_defines.dart';
import 'package:flutter_starter/core/config/env_config.dart';
import 'package:flutter_test/flutter_test.dart';

const _assetChannel = 'flutter/assets';

/// Why a define-path test cannot run, or null when the defines are set.
final String? _needsDefines =
    DartDefines.lookup('ENABLE_SSL_PINNING') == 'true' &&
        DartDefines.lookup('API_CONNECT_TIMEOUT') == '60' &&
        DartDefines.lookup('API_TIMEOUT') == '2.5'
    ? null
    : 'run with --dart-define=ENABLE_SSL_PINNING=true '
          '--dart-define=API_CONNECT_TIMEOUT=60 --dart-define=API_TIMEOUT=2.5';

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

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(_assetChannel, null);
  });

  group('criterion 1: a .env without the key falls through to the define', () {
    setUp(() => loadEnv(['BASE_URL=https://api.example.com']));

    test('getBool', () {
      expect(EnvConfig.has('ENABLE_SSL_PINNING'), isTrue);
      expect(EnvConfig.get('ENABLE_SSL_PINNING'), 'true');
      expect(EnvConfig.getBool('ENABLE_SSL_PINNING'), isTrue);
      expect(AppConfig.enableSslPinning, isTrue);
    }, skip: _needsDefines);

    test('getInt', () {
      expect(EnvConfig.getInt('API_CONNECT_TIMEOUT', defaultValue: 10), 60);
      expect(AppConfig.apiConnectTimeout, 60);
    }, skip: _needsDefines);

    test('getDouble', () {
      expect(EnvConfig.getDouble('API_TIMEOUT'), 2.5);
    }, skip: _needsDefines);

    test('a key in neither source still gets the default', () {
      expect(EnvConfig.getBool('NOT_A_KEY', defaultValue: true), isTrue);
      expect(EnvConfig.getInt('NOT_A_KEY', defaultValue: 7), 7);
      expect(EnvConfig.getDouble('NOT_A_KEY', defaultValue: 1.5), 1.5);
    });
  });

  group('the .env still wins when it has the key', () {
    test('over the define', () async {
      await loadEnv([
        'ENABLE_SSL_PINNING=false',
        'API_CONNECT_TIMEOUT=15',
        'API_TIMEOUT=4.0',
      ]);

      expect(
        EnvConfig.getBool('ENABLE_SSL_PINNING', defaultValue: true),
        isFalse,
      );
      expect(EnvConfig.getInt('API_CONNECT_TIMEOUT'), 15);
      expect(EnvConfig.getDouble('API_TIMEOUT'), 4.0);
    });
  });

  group('criterion 2: .env booleans parse the way the doc says', () {
    for (final value in ['true', 'TRUE', '1', 'yes', 'Yes', 'on', 'ON']) {
      test('"$value" is true', () async {
        await loadEnv(['FLAG=$value']);

        expect(EnvConfig.getBool('FLAG'), isTrue);
      });
    }

    for (final value in ['false', '0', 'no', 'off', 'nonsense']) {
      test('"$value" is false', () async {
        await loadEnv(['FLAG=$value']);

        expect(EnvConfig.getBool('FLAG', defaultValue: true), isFalse);
      });
    }
  });
}
