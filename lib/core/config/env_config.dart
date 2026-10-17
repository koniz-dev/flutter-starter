import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_starter/core/config/dart_defines.dart';

/// Environment configuration loader with fallback chain:
/// 1. A loaded .env file - see [load]; normally there is none
/// 2. --dart-define flags, on every platform including Flutter web, for the
///    keys listed in [DartDefines.values]. This is how `.env` reaches a build:
///    `flutter run --dart-define-from-file=.env`, with nothing bundled
/// 3. Default values
///
/// Dart-define reads go through the compile-time [DartDefines] table rather
/// than `String.fromEnvironment(key)`. A runtime-keyed `String.fromEnvironment`
/// call is not const and therefore always returns `''` in AOT (release and
/// profile) builds, and dart2js does not support it at all. The const table
/// is resolved by every compiler, dart2js included, which is why web needs no
/// special case (koniz-dev/flutter-starter#278).
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
  /// to --dart-define flags or default values.
  ///
  /// [load] reads from the asset bundle, so it only finds a file that is
  /// bundled into the app - and a bundled `.env` ships, readable, inside every
  /// release build and over HTTP on web, which `tool/check_env_assets.dart`
  /// refuses. Pass `.env` as a build input instead:
  /// `--dart-define-from-file=.env`, the second step of the fallback chain
  /// on [EnvConfig]. See "Never
  /// ship a secret in the bundle" in `docs/guides/configuration.md`
  /// (koniz-dev/flutter-starter#546).
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
  /// 2. --dart-define flag value
  /// 3. Default value (if provided)
  ///
  /// Parameters:
  /// - [key]: The environment variable key
  /// - [defaultValue]: Optional default value if not found in .env or
  ///   --dart-define
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
        // Variable not found in .env, continue to next priority
      }
    }

    // Priority 2: Check --dart-define flags
    final dartDefineValue = DartDefines.lookup(key);
    if (dartDefineValue.isNotEmpty) {
      return dartDefineValue;
    }

    // Priority 3: Return default value
    return defaultValue;
  }

  /// Get environment variable as boolean
  ///
  /// Follows the same priority order as [get]: `.env`, then
  /// `--dart-define`, then [defaultValue] when neither has the key.
  ///
  /// Returns true for: 'true', '1', 'yes', 'on' (case-insensitive, trimmed),
  /// and false for any other value that is present.
  ///
  /// The typed getters used to ask dotenv with `fallback: defaultValue`,
  /// which returns the fallback for a missing key instead of throwing, so a
  /// `.env` without the key hid its `--dart-define`; dotenv also rejected
  /// `yes` and `on` (koniz-dev/flutter-starter#322). They now parse the
  /// string [get] resolves.
  static bool getBool(String key, {bool defaultValue = false}) {
    final value = get(key).trim().toLowerCase();
    if (value.isEmpty) return defaultValue;
    return const {'true', '1', 'yes', 'on'}.contains(value);
  }

  /// Get environment variable as integer
  ///
  /// Same priority order as [get]. Returns [defaultValue] when neither source
  /// has the key or the value is not an integer.
  static int getInt(String key, {int defaultValue = 0}) =>
      int.tryParse(get(key).trim()) ?? defaultValue;

  /// Get environment variable as double
  ///
  /// Same priority order as [get]. Returns [defaultValue] when neither source
  /// has the key or the value is not a number.
  static double getDouble(String key, {double defaultValue = 0.0}) =>
      double.tryParse(get(key).trim()) ?? defaultValue;

  /// Check if an environment variable exists
  ///
  /// Returns true if the variable exists in .env file or --dart-define
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
    // Check --dart-define flags
    return DartDefines.lookup(key).isNotEmpty;
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

    // Note: --dart-define values are compile-time only. They are not merged
    // in here; read them through [get]/[getBool]/[getInt]/[getDouble], which
    // consult the compile-time [DartDefines.values] table.
    return env;
  }

  /// Check if EnvConfig has been initialized
  static bool get isInitialized => _isInitialized;
}
