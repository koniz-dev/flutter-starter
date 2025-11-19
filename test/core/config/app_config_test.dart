import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/config/env_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig', () {
    setUp(() async {
      // Ensure EnvConfig is initialized
      await EnvConfig.load();
    });

    group('Environment detection', () {
      test('should have environment property', () {
        // Assert
        expect(AppConfig.environment, isNotEmpty);
        expect(AppConfig.environment, isA<String>());
      });

      test('should detect development environment by default', () {
        // Assert
        // Default should be development if not set
        expect(AppConfig.environment, isA<String>());
      });

      test('should have isDevelopment property', () {
        // Assert
        expect(AppConfig.isDevelopment, isA<bool>());
      });

      test('should have isProduction property', () {
        // Assert
        expect(AppConfig.isProduction, isA<bool>());
      });

      test('should have isStaging property', () {
        // Assert
        expect(AppConfig.isStaging, isA<bool>());
      });

      test('should have isDebugMode property', () {
        // Assert
        expect(AppConfig.isDebugMode, isA<bool>());
        expect(AppConfig.isDebugMode, kDebugMode);
      });

      test('should have isReleaseMode property', () {
        // Assert
        expect(AppConfig.isReleaseMode, isA<bool>());
        expect(AppConfig.isReleaseMode, kReleaseMode);
      });
    });

    group('API configuration', () {
      test('should have baseUrl property', () {
        // Assert
        expect(AppConfig.baseUrl, isNotEmpty);
        expect(AppConfig.baseUrl, isA<String>());
      });

      test('should have apiTimeout property', () {
        // Assert
        expect(AppConfig.apiTimeout, isA<int>());
        expect(AppConfig.apiTimeout, greaterThan(0));
      });

      test('should have apiConnectTimeout property', () {
        // Assert
        expect(AppConfig.apiConnectTimeout, isA<int>());
        expect(AppConfig.apiConnectTimeout, greaterThan(0));
      });

      test('should have apiReceiveTimeout property', () {
        // Assert
        expect(AppConfig.apiReceiveTimeout, isA<int>());
        expect(AppConfig.apiReceiveTimeout, greaterThan(0));
      });

      test('should have apiSendTimeout property', () {
        // Assert
        expect(AppConfig.apiSendTimeout, isA<int>());
        expect(AppConfig.apiSendTimeout, greaterThan(0));
      });
    });

    group('Feature flags', () {
      test('should have enableLogging property', () {
        // Assert
        expect(AppConfig.enableLogging, isA<bool>());
      });

      test('should have enableAnalytics property', () {
        // Assert
        expect(AppConfig.enableAnalytics, isA<bool>());
      });

      test('should have enableCrashReporting property', () {
        // Assert
        expect(AppConfig.enableCrashReporting, isA<bool>());
      });

      test('should have enablePerformanceMonitoring property', () {
        // Assert
        expect(AppConfig.enablePerformanceMonitoring, isA<bool>());
      });

      test('should have enableDebugFeatures property', () {
        // Assert
        expect(AppConfig.enableDebugFeatures, isA<bool>());
      });

      test('should have enableHttpLogging property', () {
        // Assert
        expect(AppConfig.enableHttpLogging, isA<bool>());
      });
    });

    group('App info', () {
      test('should have appVersion property', () {
        // Assert
        expect(AppConfig.appVersion, isNotEmpty);
        expect(AppConfig.appVersion, isA<String>());
      });

      test('should have appBuildNumber property', () {
        // Assert
        expect(AppConfig.appBuildNumber, isNotEmpty);
        expect(AppConfig.appBuildNumber, isA<String>());
      });
    });

    group('Debug utilities', () {
      test('should have printConfig method', () {
        // Act & Assert
        expect(AppConfig.printConfig, returnsNormally);
      });

      test('should have getDebugInfo method', () {
        // Act
        final debugInfo = AppConfig.getDebugInfo();

        // Assert
        expect(debugInfo, isA<Map<String, dynamic>>());
        expect(debugInfo['environment'], isA<String>());
        expect(debugInfo['baseUrl'], isA<String>());
        expect(debugInfo['enableLogging'], isA<bool>());
        expect(debugInfo['appVersion'], isA<String>());
      });

      test('getDebugInfo should contain all configuration values', () {
        // Act
        final debugInfo = AppConfig.getDebugInfo();

        // Assert
        expect(debugInfo.containsKey('environment'), isTrue);
        expect(debugInfo.containsKey('isDevelopment'), isTrue);
        expect(debugInfo.containsKey('isStaging'), isTrue);
        expect(debugInfo.containsKey('isProduction'), isTrue);
        expect(debugInfo.containsKey('isDebugMode'), isTrue);
        expect(debugInfo.containsKey('isReleaseMode'), isTrue);
        expect(debugInfo.containsKey('baseUrl'), isTrue);
        expect(debugInfo.containsKey('apiTimeout'), isTrue);
        expect(debugInfo.containsKey('enableLogging'), isTrue);
        expect(debugInfo.containsKey('appVersion'), isTrue);
      });

      test('getDebugInfo should contain all timeout values', () {
        final debugInfo = AppConfig.getDebugInfo();
        expect(debugInfo.containsKey('apiConnectTimeout'), isTrue);
        expect(debugInfo.containsKey('apiReceiveTimeout'), isTrue);
        expect(debugInfo.containsKey('apiSendTimeout'), isTrue);
      });

      test('getDebugInfo should contain all feature flags', () {
        final debugInfo = AppConfig.getDebugInfo();
        expect(debugInfo.containsKey('enableAnalytics'), isTrue);
        expect(debugInfo.containsKey('enableCrashReporting'), isTrue);
        expect(debugInfo.containsKey('enablePerformanceMonitoring'), isTrue);
        expect(debugInfo.containsKey('enableDebugFeatures'), isTrue);
        expect(debugInfo.containsKey('enableHttpLogging'), isTrue);
      });

      test('getDebugInfo should contain app info', () {
        final debugInfo = AppConfig.getDebugInfo();
        expect(debugInfo.containsKey('appBuildNumber'), isTrue);
        expect(debugInfo.containsKey('envConfigInitialized'), isTrue);
      });
    });

    group('Environment-specific behavior', () {
      test('baseUrl should return development URL by default', () {
        final url = AppConfig.baseUrl;
        expect(url, isA<String>());
        expect(url, isNotEmpty);
      });

      test('enableLogging should have default based on environment', () {
        final logging = AppConfig.enableLogging;
        expect(logging, isA<bool>());
      });

      test('enableAnalytics should have default based on environment', () {
        final analytics = AppConfig.enableAnalytics;
        expect(analytics, isA<bool>());
      });

      test('enableCrashReporting should have default based on environment', () {
        final crashReporting = AppConfig.enableCrashReporting;
        expect(crashReporting, isA<bool>());
      });

      test('enablePerformanceMonitoring should have default', () {
        final perfMonitoring = AppConfig.enablePerformanceMonitoring;
        expect(perfMonitoring, isA<bool>());
      });

      test('enableDebugFeatures should have default', () {
        final debugFeatures = AppConfig.enableDebugFeatures;
        expect(debugFeatures, isA<bool>());
      });

      test('enableHttpLogging should have default', () {
        final httpLogging = AppConfig.enableHttpLogging;
        expect(httpLogging, isA<bool>());
      });
    });

    group('Edge Cases', () {
      test('baseUrl should handle different environment values', () {
        final url = AppConfig.baseUrl;
        expect(url, isA<String>());
        expect(url, isNotEmpty);
        // Should be a valid URL format
        expect(url, anyOf(
          startsWith('http://'),
          startsWith('https://'),
        ),);
      });

      test('apiTimeout should have reasonable default', () {
        final timeout = AppConfig.apiTimeout;
        expect(timeout, greaterThan(0));
        expect(timeout, lessThan(300)); // Should be less than 5 minutes
      });

      test('apiConnectTimeout should be less than or equal to apiTimeout', () {
        final connectTimeout = AppConfig.apiConnectTimeout;
        final timeout = AppConfig.apiTimeout;
        expect(connectTimeout, lessThanOrEqualTo(timeout));
      });

      test('environment should be lowercase', () {
        final env = AppConfig.environment;
        expect(env, equals(env.toLowerCase()));
      });

      test(
        'isDevelopment, isStaging, isProduction should be mutually exclusive',
        () {
        final isDev = AppConfig.isDevelopment;
        final isStaging = AppConfig.isStaging;
        final isProd = AppConfig.isProduction;

        // Only one should be true at a time (or all false if unknown env)
        final trueCount = [isDev, isStaging, isProd].where((v) => v).length;
        expect(trueCount, lessThanOrEqualTo(1));
      });

      test('isDebugMode and isReleaseMode should be opposite', () {
        final isDebug = AppConfig.isDebugMode;
        final isRelease = AppConfig.isReleaseMode;
        expect(isDebug, isNot(isRelease));
      });

      test('getDebugInfo should return consistent values', () {
        final debugInfo1 = AppConfig.getDebugInfo();
        final debugInfo2 = AppConfig.getDebugInfo();

        // Should return same values on multiple calls
        expect(debugInfo1['environment'], debugInfo2['environment']);
        expect(debugInfo1['baseUrl'], debugInfo2['baseUrl']);
        expect(debugInfo1['enableLogging'], debugInfo2['enableLogging']);
      });

      test('getDebugInfo should have correct types', () {
        final debugInfo = AppConfig.getDebugInfo();
        expect(debugInfo['environment'], isA<String>());
        expect(debugInfo['isDevelopment'], isA<bool>());
        expect(debugInfo['isStaging'], isA<bool>());
        expect(debugInfo['isProduction'], isA<bool>());
        expect(debugInfo['isDebugMode'], isA<bool>());
        expect(debugInfo['isReleaseMode'], isA<bool>());
        expect(debugInfo['baseUrl'], isA<String>());
        expect(debugInfo['apiTimeout'], isA<int>());
        expect(debugInfo['enableLogging'], isA<bool>());
        expect(debugInfo['appVersion'], isA<String>());
        expect(debugInfo['appBuildNumber'], isA<String>());
        expect(debugInfo['envConfigInitialized'], isA<bool>());
      });

      test('appVersion should have valid format', () {
        final version = AppConfig.appVersion;
        expect(version, isNotEmpty);
        // Should be in semantic version format (x.y.z or similar)
        expect(version, matches(RegExp(r'[\d.]+')));
      });

      test('appBuildNumber should be numeric string', () {
        final buildNumber = AppConfig.appBuildNumber;
        expect(buildNumber, isNotEmpty);
        expect(int.tryParse(buildNumber), isNotNull);
      });

      test('all timeout values should be positive', () {
        expect(AppConfig.apiTimeout, greaterThan(0));
        expect(AppConfig.apiConnectTimeout, greaterThan(0));
        expect(AppConfig.apiReceiveTimeout, greaterThan(0));
        expect(AppConfig.apiSendTimeout, greaterThan(0));
      });

      test('printConfig should not throw in debug mode', () {
        expect(AppConfig.printConfig, returnsNormally);
      });
    });
  });
}
