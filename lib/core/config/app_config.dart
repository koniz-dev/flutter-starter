import 'package:flutter/foundation.dart';

/// Application configuration based on environment
class AppConfig {
  AppConfig._();

  /// Current environment name (development, staging, production)
  ///
  /// Can be set via compile-time environment variable:
  /// `--dart-define=ENVIRONMENT=production`
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

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

  /// Base URL for API requests
  ///
  /// Can be set via compile-time environment variable:
  /// `--dart-define=BASE_URL=https://api.example.com`
  static String get baseUrl => const String.fromEnvironment(
        'BASE_URL',
        defaultValue: 'https://api.example.com',
      );

  /// Returns true if logging should be enabled
  ///
  /// Enabled in development and staging environments
  static bool get enableLogging => isDevelopment || isStaging;

  /// Returns true if analytics should be enabled
  ///
  /// Enabled in production and staging environments
  static bool get enableAnalytics => isProduction || isStaging;
}
