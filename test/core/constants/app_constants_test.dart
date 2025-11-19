import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConstants', () {
    test('should have appName constant', () {
      expect(AppConstants.appName, isA<String>());
      expect(AppConstants.appName, isNotEmpty);
      expect(AppConstants.appName, 'Flutter Starter');
    });

    test('should have defaultPageSize constant', () {
      expect(AppConstants.defaultPageSize, isA<int>());
      expect(AppConstants.defaultPageSize, 20);
      expect(AppConstants.defaultPageSize, greaterThan(0));
    });

    test('should have maxPageSize constant', () {
      expect(AppConstants.maxPageSize, isA<int>());
      expect(AppConstants.maxPageSize, 100);
      expect(
        AppConstants.maxPageSize,
        greaterThan(AppConstants.defaultPageSize),
      );
    });

    test('should have tokenKey constant', () {
      expect(AppConstants.tokenKey, isA<String>());
      expect(AppConstants.tokenKey, 'auth_token');
    });

    test('should have refreshTokenKey constant', () {
      expect(AppConstants.refreshTokenKey, isA<String>());
      expect(AppConstants.refreshTokenKey, 'refresh_token');
    });

    test('should have userDataKey constant', () {
      expect(AppConstants.userDataKey, isA<String>());
      expect(AppConstants.userDataKey, 'user_data');
    });

    test('should have themeKey constant', () {
      expect(AppConstants.themeKey, isA<String>());
      expect(AppConstants.themeKey, 'theme_mode');
    });

    test('should have languageKey constant', () {
      expect(AppConstants.languageKey, isA<String>());
      expect(AppConstants.languageKey, 'language');
    });

    test('should have all storage keys defined', () {
      expect(AppConstants.tokenKey, isNotEmpty);
      expect(AppConstants.refreshTokenKey, isNotEmpty);
      expect(AppConstants.userDataKey, isNotEmpty);
      expect(AppConstants.themeKey, isNotEmpty);
      expect(AppConstants.languageKey, isNotEmpty);
    });

    test('should have valid pagination constants', () {
      expect(
        AppConstants.defaultPageSize,
        lessThanOrEqualTo(AppConstants.maxPageSize),
      );
      expect(AppConstants.defaultPageSize, greaterThan(0));
      expect(AppConstants.maxPageSize, greaterThan(0));
    });

    test('should have unique storage keys', () {
      final keys = [
        AppConstants.tokenKey,
        AppConstants.refreshTokenKey,
        AppConstants.userDataKey,
        AppConstants.themeKey,
        AppConstants.languageKey,
      ];
      // All keys should be unique
      expect(keys.toSet().length, keys.length);
    });

    test('should have non-empty storage keys', () {
      expect(AppConstants.tokenKey.length, greaterThan(0));
      expect(AppConstants.refreshTokenKey.length, greaterThan(0));
      expect(AppConstants.userDataKey.length, greaterThan(0));
      expect(AppConstants.themeKey.length, greaterThan(0));
      expect(AppConstants.languageKey.length, greaterThan(0));
    });

    test('should have valid page size relationship', () {
      expect(AppConstants.defaultPageSize, lessThan(AppConstants.maxPageSize));
      expect(AppConstants.maxPageSize % AppConstants.defaultPageSize, 0);
    });

    test('should have appName as non-empty string', () {
      expect(AppConstants.appName, isNotEmpty);
      expect(AppConstants.appName.length, greaterThan(0));
    });
  });
}
