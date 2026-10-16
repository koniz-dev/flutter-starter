// An ENVIRONMENT outside the three known names must be reported, not
// silently treated as "none of them" (koniz-dev/flutter-starter#321).
//
// `AppConfig.environment` was only lower-cased. `prod`, or `production` with
// a trailing space, made isDevelopment, isStaging and isProduction all false,
// so baseUrl fell through to http://localhost:3000 and SSL pinning was off -
// a release built with a typo shipped pointing at localhost, unpinned, with
// no warning.
//
// The values are fed through a `.env` asset rather than `--dart-define`,
// because a dart-define is a compile-time constant: one test run could only
// ever see one value.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/config/env_config.dart';
import 'package:flutter_test/flutter_test.dart';

const _assetChannel = 'flutter/assets';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var loads = 0;

  /// Loads a `.env` whose only line is [line], under a fresh asset name so
  /// the asset bundle's string cache cannot hand back the previous one.
  Future<void> loadEnv(String line) async {
    final name = 'env_${loads++}';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(_assetChannel, (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key != name) return null;
          final bytes = Uint8List.fromList(utf8.encode('$line\n'));
          return ByteData.view(bytes.buffer);
        });
    await EnvConfig.load(fileName: name);
    expect(EnvConfig.isInitialized, isTrue, reason: 'the .env must load');
  }

  tearDownAll(() async {
    await loadEnv('ENVIRONMENT=development');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(_assetChannel, null);
  });

  // Runs first, before any .env is loaded, so it sees the dart-define path:
  // run the file with --dart-define=ENVIRONMENT=prod or ="production " to
  // exercise it.
  test('the compile-time define alone is trimmed and checked the same way '
      '(${AppConfig.environment})', () {
    expect(EnvConfig.isInitialized, isFalse);
    final raw = EnvConfig.get('ENVIRONMENT', defaultValue: 'development');

    expect(AppConfig.environment, raw.trim().toLowerCase());
    expect(
      AppConfig.environmentMisconfigured,
      !AppConfig.knownEnvironments.contains(raw.trim().toLowerCase()),
    );
    // ignore: avoid_print - the line is the evidence for the define path
    print(
      'VP define=${jsonEncode(raw)} environment=${AppConfig.environment} '
      'misconfigured=${AppConfig.environmentMisconfigured} '
      'baseUrl=${AppConfig.baseUrl}',
    );
  });

  group('criterion 1: an unknown ENVIRONMENT is surfaced', () {
    for (final value in ['prod', 'qa', 'Production-EU']) {
      test('ENVIRONMENT=$value', () async {
        await loadEnv('ENVIRONMENT=$value');

        expect(AppConfig.environment, value.toLowerCase());
        expect(AppConfig.environmentMisconfigured, isTrue);
        expect(AppConfig.getDebugInfo()['environmentMisconfigured'], isTrue);
        // What the flag is warning about: none of the three matches.
        expect(AppConfig.isProduction, isFalse);
        expect(AppConfig.isStaging, isFalse);
        expect(AppConfig.isDevelopment, isFalse);
      });
    }

    test('printConfig warns about it', () async {
      await loadEnv('ENVIRONMENT=prod');
      final printed = <String>[];
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
      addTearDown(() => debugPrint = original);

      AppConfig.printConfig();

      expect(
        printed.where((l) => l.contains('ENVIRONMENT MISCONFIGURED')),
        hasLength(1),
        reason: printed.join('\n'),
      );
      expect(
        printed.join('\n'),
        contains(AppConfig.knownEnvironments.join(', ')),
      );
    });

    for (final value in ['development', 'staging', 'production']) {
      test('ENVIRONMENT=$value is not flagged', () async {
        await loadEnv('ENVIRONMENT=$value');

        expect(AppConfig.environmentMisconfigured, isFalse);
      });
    }
  });

  group('criterion 2: the value is trimmed before comparison', () {
    test('"production " (trailing space) is production', () async {
      await loadEnv('ENVIRONMENT="production "');
      // The quotes keep the space through the .env parser, so this is the
      // value a mistyped define or CI variable would carry.
      expect(EnvConfig.get('ENVIRONMENT'), 'production ');

      expect(AppConfig.environment, 'production');
      expect(AppConfig.isProduction, isTrue);
      expect(AppConfig.environmentMisconfigured, isFalse);
      expect(AppConfig.baseUrl, 'https://api.example.com');
      expect(AppConfig.enableSslPinning, isTrue);
    });

    test('" Staging" (leading space, capital) is staging', () async {
      await loadEnv('ENVIRONMENT=" Staging"');

      expect(AppConfig.environment, 'staging');
      expect(AppConfig.isStaging, isTrue);
      expect(AppConfig.environmentMisconfigured, isFalse);
    });
  });
}
