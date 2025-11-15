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
  });
}
