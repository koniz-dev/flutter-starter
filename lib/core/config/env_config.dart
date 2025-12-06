import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration loader with fallback chain:
/// 1. .env file (for local development)
/// 2. Default values
///
/// Note: --dart-define flags are compile-time only and cannot be accessed
/// dynamically at runtime. They must be accessed via const
/// String.fromEnvironment() for specific known keys if needed.
///
/// Usage:
/// ```dart
/// await EnvConfig.load();
/// final value = EnvConfig.get('BASE_URL');
/// ```
class EnvConfig {
  EnvConfig._();

  static bool _isInitialized = false;

  /// Load environment variables from .env file
  ///
  /// This should be called before runApp() in main.dart
  ///
  /// The .env file is optional. If it doesn't exist, the system will fall back
  /// to default values.
  ///
  /// Note: For .env to be loaded, it must be added to pubspec.yaml assets
  /// after creating it from .env.example
  ///
  /// Example:
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await EnvConfig.load();
  ///   runApp(MyApp());
  /// }
  /// ```
  static Future<void> load({String fileName = '.env'}) async {
    try {
      await dotenv.load(fileName: fileName);
      _isInitialized = true;
    } on Exception catch (_) {
      // .env file is optional - fallback to --dart-define or defaults
      // This is expected in CI/CD environments where .env files aren't used
      _isInitialized = false;
    } on Object catch (_) {
      // Catch all other errors (FileNotFoundError, etc.)
      // .env file is optional - fallback to --dart-define or defaults
      _isInitialized = false;
    }
  }

  /// Get environment variable with fallback chain:
  /// 1. .env file value (if loaded)
  /// 2. Default value (if provided)
  ///
  /// Parameters:
  /// - [key]: The environment variable key
  /// - [defaultValue]: Optional default value if not found in .env
  ///
  /// Returns:
  /// The environment variable value, or [defaultValue] if not found
  ///
  /// Example:
  /// ```dart
  /// final baseUrl = EnvConfig.get(
  ///   'BASE_URL',
  ///   defaultValue: 'https://api.example.com',
  /// );
  /// ```
  static String get(String key, {String defaultValue = ''}) {
    // Priority 1: Check .env file (if loaded)
    // Use dotenv.get() with fallback for better null safety support
    if (_isInitialized) {
      try {
        final value = dotenv.get(key, fallback: '');
        if (value.isNotEmpty) {
          return value;
        }
      } on Exception {
        // Variable not found in .env, continue to default
      }
    }

    // Return default value
    // Note: --dart-define flags are compile-time only and cannot be
    // accessed dynamically at runtime. They must be accessed via
    // const String.fromEnvironment() for specific known keys.
    return defaultValue;
  }

  /// Get environment variable as boolean
  ///
  /// Returns true for: 'true', '1', 'yes', 'on' (case-insensitive)
  /// Returns false otherwise or if not found
  static bool getBool(String key, {bool defaultValue = false}) {
    // Priority 1: Check .env file (if loaded)
    if (_isInitialized) {
      try {
        return dotenv.getBool(key, fallback: defaultValue);
      } on Exception {
        // Variable not found in .env, continue to default
      }
    }

    // Return default value
    return defaultValue;
  }

  /// Get environment variable as integer
  ///
  /// Returns parsed integer value or defaultValue if not found or invalid
  static int getInt(String key, {int defaultValue = 0}) {
    // Priority 1: Check .env file (if loaded)
    if (_isInitialized) {
      try {
        return dotenv.getInt(key, fallback: defaultValue);
      } on Exception {
        // Variable not found in .env, continue to default
      }
    }

    // Return default value
    return defaultValue;
  }

  /// Get environment variable as double
  ///
  /// Returns parsed double value or defaultValue if not found or invalid
  static double getDouble(String key, {double defaultValue = 0.0}) {
    // Priority 1: Check .env file (if loaded)
    if (_isInitialized) {
      try {
        return dotenv.getDouble(key, fallback: defaultValue);
      } on Exception {
        // Variable not found in .env, continue to default
      }
    }

    // Return default value
    return defaultValue;
  }

  /// Check if an environment variable exists
  ///
  /// Returns true if the variable exists in .env file
  static bool has(String key) {
    // Check .env file (if loaded)
    if (_isInitialized) {
      try {
        final value = dotenv.maybeGet(key);
        if (value != null && value.isNotEmpty) {
          return true;
        }
      } on Exception {
        // Variable not found in .env
      }
    }
    // Note: --dart-define values cannot be checked dynamically at runtime
    return false;
  }

  /// Get all environment variables as a map
  ///
  /// Useful for debugging or logging configuration
  static Map<String, String> getAll() {
    final env = <String, String>{};

    // Add .env file values
    if (_isInitialized) {
      env.addAll(dotenv.env);
    }

    // Note: --dart-define values are compile-time only and cannot be
    // enumerated at runtime. They must be accessed via String.fromEnvironment()
    return env;
  }

  /// Check if EnvConfig has been initialized
  static bool get isInitialized => _isInitialized;
}
