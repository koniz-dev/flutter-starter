// AppConfig.hasBackend is the one rule for "is there a backend": demo auth
// keys on it (pinned beside the demo, so that removing the demo removes
// that test too), and the development baseUrl fallback is only reachable
// when it is false outside a debug build.

import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig.hasBackendFor', () {
    test('development with no BASE_URL has no backend', () {
      expect(
        AppConfig.hasBackendFor(environment: 'development', baseUrl: ''),
        isFalse,
      );
      expect(
        AppConfig.hasBackendFor(environment: 'development', baseUrl: '  '),
        isFalse,
      );
    });

    test('a BASE_URL is a backend, a local server included', () {
      expect(
        AppConfig.hasBackendFor(
          environment: 'development',
          baseUrl: 'http://localhost:3000',
        ),
        isTrue,
      );
    });

    for (final environment in ['staging', 'production']) {
      test('$environment always has one, through its default baseUrl', () {
        expect(
          AppConfig.hasBackendFor(environment: environment, baseUrl: ''),
          isTrue,
        );
      });
    }
  });

  test('this test run: development, no BASE_URL, so no backend', () {
    expect(AppConfig.environment, 'development');
    expect(AppConfig.hasBackend, isFalse);
  });
}
