// The dart-define path of ENVIRONMENT, with no `.env` loaded: trimmed,
// lower-cased and checked against the known three exactly as a `.env` value is
// (koniz-dev/flutter-starter#321).
//
// It has a file of its own because it needs `EnvConfig` uninitialized, and
// every test in unknown_environment_test.dart loads a `.env`. There it relied
// on running first, which a shuffled order breaks
// (koniz-dev/flutter-starter#602). `flutter test` runs each file in its own
// isolate, so nothing here can have loaded one.
//
// Run with --dart-define=ENVIRONMENT=prod or ="production " to exercise a
// misconfigured define.

import 'dart:convert';

import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/config/env_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
}
