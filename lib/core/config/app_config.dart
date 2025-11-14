import 'package:flutter/foundation.dart';

/// Application configuration based on environment
class AppConfig {
  AppConfig._();

  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => environment == 'production';
  static bool get isStaging => environment == 'staging';

  static bool get isDebugMode => kDebugMode;
  static bool get isReleaseMode => kReleaseMode;

  // API Configuration
  static String get baseUrl => const String.fromEnvironment(
        'BASE_URL',
        defaultValue: 'https://api.example.com',
      );

  // Feature Flags
  static bool get enableLogging => isDevelopment || isStaging;
  static bool get enableAnalytics => isProduction || isStaging;
}

