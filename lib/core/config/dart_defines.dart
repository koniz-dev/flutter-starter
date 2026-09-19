/// Compile-time table of every `--dart-define` value the app understands.
///
/// ## Why this file exists
///
/// `String.fromEnvironment` is a **const** constructor. The SDK documents that
/// it "is only guaranteed to work when invoked as `const`" - ahead-of-time
/// compiled platforms (release/profile builds for Android, iOS, macOS, and
/// Windows) have no access to compiler options at run time, so a non-const
/// invocation returns the empty string there.
///
/// A call whose key is a runtime variable, such as
/// `String.fromEnvironment(key)`, can never be const. Every such call silently
/// returned `''` in release builds, which meant `--dart-define` never reached
/// [EnvConfig](env_config.dart) and release builds fell through to the
/// hardcoded development defaults.
///
/// The fix is this table: each key is spelled out once as a literal inside a
/// `const` map, so the compiler resolves it at build time. Runtime lookups then
/// index the already-resolved map instead of asking the environment.
///
/// ## Adding a key
///
/// Add it to `.env.example` **and** to `DartDefines.values`.
/// `test/core/config/dart_defines_test.dart` fails if the two drift apart.
library;

/// Compile-time `--dart-define` values, resolved once per build.
///
/// See the library documentation for why a const table is required.
class DartDefines {
  DartDefines._();

  /// Every supported `--dart-define` key mapped to its compile-time value.
  ///
  /// Keys absent from the build command resolve to the empty string, which
  /// callers treat as "not supplied".
  ///
  /// This map must be `const` and every [String.fromEnvironment] argument must
  /// be a string literal. Replacing a literal with a variable reintroduces the
  /// bug this table exists to fix.
  static const Map<String, String> values = <String, String>{
    // Environment
    'ENVIRONMENT': String.fromEnvironment('ENVIRONMENT'),

    // API configuration
    'BASE_URL': String.fromEnvironment('BASE_URL'),
    'API_TIMEOUT': String.fromEnvironment('API_TIMEOUT'),
    'API_CONNECT_TIMEOUT': String.fromEnvironment('API_CONNECT_TIMEOUT'),
    'API_RECEIVE_TIMEOUT': String.fromEnvironment('API_RECEIVE_TIMEOUT'),
    'API_SEND_TIMEOUT': String.fromEnvironment('API_SEND_TIMEOUT'),
    'API_SSL_FINGERPRINTS': String.fromEnvironment('API_SSL_FINGERPRINTS'),
    'ENABLE_SSL_PINNING': String.fromEnvironment('ENABLE_SSL_PINNING'),

    // Feature flags
    'ENABLE_LOGGING': String.fromEnvironment('ENABLE_LOGGING'),
    'ENABLE_ANALYTICS': String.fromEnvironment('ENABLE_ANALYTICS'),
    'ENABLE_CRASH_REPORTING': String.fromEnvironment('ENABLE_CRASH_REPORTING'),
    'ENABLE_PERFORMANCE_MONITORING': String.fromEnvironment(
      'ENABLE_PERFORMANCE_MONITORING',
    ),
    'ENABLE_DEBUG_FEATURES': String.fromEnvironment('ENABLE_DEBUG_FEATURES'),
    'ENABLE_HTTP_LOGGING': String.fromEnvironment('ENABLE_HTTP_LOGGING'),

    // App information
    'APP_VERSION': String.fromEnvironment('APP_VERSION'),
    'APP_BUILD_NUMBER': String.fromEnvironment('APP_BUILD_NUMBER'),
  };

  /// The value supplied for [key] via `--dart-define`, or `''`.
  ///
  /// Returns `''` for any key that is not in [values]: an unknown key cannot be
  /// read from a dart-define at all, because resolving it would require the
  /// non-const call that does not work in AOT builds. Unknown keys are still
  /// readable from a `.env` file.
  static String lookup(String key) => values[key] ?? '';

  /// Whether [key] has a table entry, regardless of whether a value was given.
  static bool isKnown(String key) => values.containsKey(key);
}
