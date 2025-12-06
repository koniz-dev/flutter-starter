import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/config/env_config.dart';

/// Application configuration with environment-aware defaults
///
/// This class provides typed access to configuration values with:
/// - Environment-aware defaults
/// - Feature flags
/// - Network timeout configuration
/// - Debug utilities
///
/// Usage:
/// ```dart
/// final baseUrl = AppConfig.baseUrl;
/// if (AppConfig.enableLogging) {
///   logger.info('App started');
/// }
/// ```
class AppConfig {
  AppConfig._();

  // ==========================================================================
  // Environment Detection
  // ==========================================================================

  /// Current environment name (development, staging, production)
  ///
  /// Can be set via:
  /// - .env file: `ENVIRONMENT=production`
  /// - --dart-define: `--dart-define=ENVIRONMENT=production`
  /// - Default: `development`
  static String get environment => EnvConfig.get(
    'ENVIRONMENT',
    defaultValue: 'development',
  ).toLowerCase();

  /// Returns true if the current environment is development
  static bool get isDevelopment => environment == 'development';

  /// Returns true if the current environment is production
  static bool get isProduction => environment == 'production';

  /// Returns true if the current environment is staging
  static bool get isStaging => environment == 'staging';

  /// Returns true if the app is running in debug mode
  static bool get isDebugMode => kDebugMode;

  /// Returns true if the app is running in release mode
  static bool get isReleaseMode => kReleaseMode;

  // ==========================================================================
  // API Configuration
  // ==========================================================================

  /// Base URL for API requests
  ///
  /// Environment-aware defaults:
  /// - Development: `http://localhost:3000`
  /// - Staging: `https://api-staging.example.com`
  /// - Production: `https://api.example.com`
  ///
  /// Can be overridden via:
  /// - .env file: `BASE_URL=https://api.example.com`
  /// - --dart-define: `--dart-define=BASE_URL=https://api.example.com`
  static String get baseUrl {
    final envValue = EnvConfig.get('BASE_URL');
    if (envValue.isNotEmpty) {
      return envValue;
    }

    // Environment-aware defaults
    switch (environment) {
      case 'production':
        return 'https://api.example.com';
      case 'staging':
        return 'https://api-staging.example.com';
      case 'development':
      default:
        return 'http://localhost:3000';
    }
  }

  /// API timeout in seconds
  ///
  /// Default: 30 seconds
  /// Can be overridden via .env: `API_TIMEOUT=60`
  static int get apiTimeout =>
      EnvConfig.getInt('API_TIMEOUT', defaultValue: 30);

  /// API connect timeout in seconds
  ///
  /// Default: 10 seconds
  /// Can be overridden via .env: `API_CONNECT_TIMEOUT=15`
  static int get apiConnectTimeout =>
      EnvConfig.getInt('API_CONNECT_TIMEOUT', defaultValue: 10);

  /// API receive timeout in seconds
  ///
  /// Default: 30 seconds
  /// Can be overridden via .env: `API_RECEIVE_TIMEOUT=60`
  static int get apiReceiveTimeout =>
      EnvConfig.getInt('API_RECEIVE_TIMEOUT', defaultValue: 30);

  /// API send timeout in seconds
  ///
  /// Default: 30 seconds
  /// Can be overridden via .env: `API_SEND_TIMEOUT=60`
  static int get apiSendTimeout =>
      EnvConfig.getInt('API_SEND_TIMEOUT', defaultValue: 30);

  // ==========================================================================
  // Feature Flags
  // ==========================================================================

  /// Enable general application logging
  ///
  /// This flag controls general application logging (e.g., debug messages,
  /// info logs, error logs). Use this for application-level logging.
  ///
  /// Default behavior:
  /// - Development: `true`
  /// - Staging: `true`
  /// - Production: `false`
  ///
  /// Can be overridden via .env: `ENABLE_LOGGING=false`
  ///
  /// See also: [enableHttpLogging] for HTTP request/response logging
  static bool get enableLogging {
    if (EnvConfig.has('ENABLE_LOGGING')) {
      return EnvConfig.getBool('ENABLE_LOGGING');
    }
    return isDevelopment || isStaging;
  }

  /// Enable analytics
  ///
  /// Default behavior:
  /// - Development: `false`
  /// - Staging: `true`
  /// - Production: `true`
  ///
  /// Can be overridden via .env: `ENABLE_ANALYTICS=true`
  static bool get enableAnalytics {
    if (EnvConfig.has('ENABLE_ANALYTICS')) {
      return EnvConfig.getBool('ENABLE_ANALYTICS');
    }
    return isProduction || isStaging;
  }

  /// Enable crash reporting
  ///
  /// Default behavior:
  /// - Development: `false`
  /// - Staging: `true`
  /// - Production: `true`
  ///
  /// Can be overridden via .env: `ENABLE_CRASH_REPORTING=true`
  static bool get enableCrashReporting {
    if (EnvConfig.has('ENABLE_CRASH_REPORTING')) {
      return EnvConfig.getBool('ENABLE_CRASH_REPORTING');
    }
    return isProduction || isStaging;
  }

  /// Enable performance monitoring
  ///
  /// Default behavior:
  /// - Development: `false`
  /// - Staging: `true`
  /// - Production: `true`
  ///
  /// Can be overridden via .env: `ENABLE_PERFORMANCE_MONITORING=true`
  static bool get enablePerformanceMonitoring {
    if (EnvConfig.has('ENABLE_PERFORMANCE_MONITORING')) {
      return EnvConfig.getBool('ENABLE_PERFORMANCE_MONITORING');
    }
    return isProduction || isStaging;
  }

  /// Enable debug features (e.g., debug menu, verbose logging)
  ///
  /// Default: `true` in development, `false` otherwise
  ///
  /// Can be overridden via .env: `ENABLE_DEBUG_FEATURES=false`
  static bool get enableDebugFeatures {
    if (EnvConfig.has('ENABLE_DEBUG_FEATURES')) {
      return EnvConfig.getBool('ENABLE_DEBUG_FEATURES');
    }
    return isDevelopment;
  }

  // ==========================================================================
  // Additional Configuration
  // ==========================================================================

  /// App version (from pubspec.yaml or environment)
  ///
  /// Can be set via .env: `APP_VERSION=1.0.0`
  static String get appVersion => EnvConfig.get(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  /// App build number
  ///
  /// Can be set via .env: `APP_BUILD_NUMBER=1`
  static String get appBuildNumber => EnvConfig.get(
    'APP_BUILD_NUMBER',
    defaultValue: '1',
  );

  /// Enable HTTP request/response logging
  ///
  /// This flag controls HTTP request/response logging specifically for
  /// network operations (e.g., API calls, request/response bodies, headers).
  /// Use this for debugging network issues.
  ///
  /// Default: `true` in development, `false` otherwise
  ///
  /// Can be overridden via .env: `ENABLE_HTTP_LOGGING=false`
  ///
  /// Note: This is separate from [enableLogging]. You can enable HTTP
  /// logging without enabling general application logging, or vice versa.
  static bool get enableHttpLogging {
    if (EnvConfig.has('ENABLE_HTTP_LOGGING')) {
      return EnvConfig.getBool('ENABLE_HTTP_LOGGING');
    }
    return isDevelopment;
  }

  // ==========================================================================
  // Debug Utilities
  // ==========================================================================

  /// Print current configuration to console
  ///
  /// Useful for debugging and verifying configuration values
  static void printConfig() {
    if (kDebugMode) {
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('📱 App Configuration');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('Environment: $environment');
      debugPrint('Debug Mode: $isDebugMode');
      debugPrint('Release Mode: $isReleaseMode');
      debugPrint('');
      debugPrint('🌐 API Configuration:');
      debugPrint('  Base URL: $baseUrl');
      debugPrint('  Timeout: ${apiTimeout}s');
      debugPrint('  Connect Timeout: ${apiConnectTimeout}s');
      debugPrint('  Receive Timeout: ${apiReceiveTimeout}s');
      debugPrint('  Send Timeout: ${apiSendTimeout}s');
      debugPrint('');
      debugPrint('🚩 Feature Flags:');
      debugPrint('  Logging: $enableLogging');
      debugPrint('  Analytics: $enableAnalytics');
      debugPrint('  Crash Reporting: $enableCrashReporting');
      debugPrint('  Performance Monitoring: $enablePerformanceMonitoring');
      debugPrint('  Debug Features: $enableDebugFeatures');
      debugPrint('  HTTP Logging: $enableHttpLogging');
      debugPrint('');
      debugPrint('📦 App Info:');
      debugPrint('  Version: $appVersion');
      debugPrint('  Build Number: $appBuildNumber');
      debugPrint('═══════════════════════════════════════════════════════════');
    }
  }

  /// Get configuration as a map for debugging
  ///
  /// Returns a map containing all configuration values
  static Map<String, dynamic> getDebugInfo() {
    return {
      'environment': environment,
      'isDevelopment': isDevelopment,
      'isStaging': isStaging,
      'isProduction': isProduction,
      'isDebugMode': isDebugMode,
      'isReleaseMode': isReleaseMode,
      'baseUrl': baseUrl,
      'apiTimeout': apiTimeout,
      'apiConnectTimeout': apiConnectTimeout,
      'apiReceiveTimeout': apiReceiveTimeout,
      'apiSendTimeout': apiSendTimeout,
      'enableLogging': enableLogging,
      'enableAnalytics': enableAnalytics,
      'enableCrashReporting': enableCrashReporting,
      'enablePerformanceMonitoring': enablePerformanceMonitoring,
      'enableDebugFeatures': enableDebugFeatures,
      'enableHttpLogging': enableHttpLogging,
      'appVersion': appVersion,
      'appBuildNumber': appBuildNumber,
      'envConfigInitialized': EnvConfig.isInitialized,
    };
  }
}
