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

  /// The environment names the rest of [AppConfig] recognises.
  ///
  /// Adding an environment means adding it here and to every switch on
  /// [environment] (`baseUrl`, the `is*` getters); until then it is reported
  /// by [environmentMisconfigured].
  static const List<String> knownEnvironments = [
    'development',
    'staging',
    'production',
  ];

  /// Current environment name (development, staging, production)
  ///
  /// Trimmed and lower-cased, so `Production ` is `production`.
  ///
  /// Can be set via:
  /// - .env file: `ENVIRONMENT=production`
  /// - --dart-define: `--dart-define=ENVIRONMENT=production`
  /// - Default: `development`
  static String get environment => EnvConfig.get(
    'ENVIRONMENT',
    defaultValue: 'development',
  ).trim().toLowerCase();

  /// Whether [environment] is none of [knownEnvironments].
  ///
  /// This is a misconfiguration, and a dangerous one: [isDevelopment],
  /// [isStaging] and [isProduction] are then all false, so [baseUrl] falls
  /// back to the development `http://localhost:3000` and [enableSslPinning]
  /// is off. `ENVIRONMENT=prod` used to do exactly that with no warning.
  /// [printConfig] reports it, and it is in
  /// [getDebugInfo].
  static bool get environmentMisconfigured =>
      !knownEnvironments.contains(environment);

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
  /// - Development: `http://localhost:3000`, which only a profile or release
  ///   build ever contacts: without `BASE_URL` a development debug build has
  ///   no backend ([hasBackend]) and signs in offline instead
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

  /// Whether this build talks to a backend: `BASE_URL` is set, or
  /// [environment] is not `development`.
  ///
  /// This is the one rule for "is there a backend". Where it is false in a
  /// debug build, auth - the only feature that calls the network - signs in
  /// with the offline demo account, so the app as a whole runs without a
  /// server and nothing contacts the development [baseUrl] fallback. To use
  /// a local server in development, set `BASE_URL` to it.
  static bool get hasBackend => hasBackendFor(
    environment: environment,
    baseUrl: EnvConfig.get('BASE_URL'),
  );

  /// The rule behind [hasBackend], with every input explicit.
  static bool hasBackendFor({
    required String environment,
    required String baseUrl,
  }) => baseUrl.trim().isNotEmpty || environment != 'development';

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

  /// List of valid SSL certificate fingerprints (SHA-256)
  ///
  /// Can be configured via .env (comma separated):
  /// `API_SSL_FINGERPRINTS=f4:34:b2...,c8:2f:13...`
  static List<String> get apiSslFingerprints {
    final envValue = EnvConfig.get('API_SSL_FINGERPRINTS');
    if (envValue.isNotEmpty) {
      return envValue
          .split(',')
          .map((s) => s.trim().replaceAll(':', '').toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  /// Enable SSL/Certificate Pinning
  ///
  /// Enforces verification of server certificate fingerprints using
  /// [apiSslFingerprints].
  /// Default behavior:
  /// - Staging/Production: `true`
  /// - Development: `true` once [apiSslFingerprints] holds any, `false`
  ///   otherwise (to allow proxy debugging like Charles/Proxyman). Configured
  ///   fingerprints are a statement that this backend is pinned; ignoring them
  ///   because the environment says development shipped releases unpinned.
  ///
  /// Can be overridden via .env: `ENABLE_SSL_PINNING=false`
  static bool get enableSslPinning {
    if (EnvConfig.has('ENABLE_SSL_PINNING')) {
      return EnvConfig.getBool('ENABLE_SSL_PINNING');
    }
    return isStaging || isProduction || apiSslFingerprints.isNotEmpty;
  }

  /// Whether a release build is configured as `development`.
  ///
  /// `development` is the default and the value `.env.example` ships, so a
  /// release built from an unedited `.env` lands here: debug routes
  /// registered, HTTP logging on, pinning off unless fingerprints are set.
  /// `main()` refuses to start on it. Profile builds are allowed - profiling
  /// against a development backend is what `--profile` is for.
  static bool releaseBuiltAsDevelopment({bool releaseMode = kReleaseMode}) =>
      releaseMode && isDevelopment;

  /// Whether certificate pinning is actually enforced.
  ///
  /// [enableSslPinning] is only the request. With no entries in
  /// [apiSslFingerprints] there is nothing to pin against, so the transport
  /// falls back to the system trust store and pinning is *not* in effect.
  ///
  /// Never in effect on Flutter web, where the browser owns TLS and
  /// `SslPinning` installs no adapter. This
  /// mirrors `SslPinning.isEffective`, so `getDebugInfo` cannot report a web
  /// build as pinned once `--dart-define` reaches web.
  static bool get sslPinningEffective =>
      !kIsWeb && enableSslPinning && apiSslFingerprints.isNotEmpty;

  /// Whether pinning is requested but unenforceable (no fingerprints).
  ///
  /// This is a misconfiguration: the app believes it is pinned and is not.
  ///
  /// Never on web either: pinning does not apply there, so an empty list
  /// misconfigures nothing.
  static bool get sslPinningMisconfigured =>
      !kIsWeb && enableSslPinning && apiSslFingerprints.isEmpty;

  /// Whether a release build requests pinning it cannot enforce.
  ///
  /// [sslPinningMisconfigured] in a release build: the assertion that flags it
  /// in debug is stripped, so the app would otherwise talk to the API through
  /// the system trust store while every default says it is pinned. `main()`
  /// refuses to start on it. Setting `ENABLE_SSL_PINNING=false` explicitly is
  /// the opt-out. Profile builds are allowed, as for
  /// [releaseBuiltAsDevelopment].
  static bool releasePinningMisconfigured({bool releaseMode = kReleaseMode}) =>
      releaseMode && sslPinningMisconfigured;

  // ==========================================================================
  // Feature Flags
  // ==========================================================================

  /// Enable general application logging
  ///
  /// This flag controls general application logging (e.g., debug messages,
  /// info logs, error logs). Use this for application-level logging.
  ///
  /// Default: `true` in every environment.
  ///
  /// Production used to default to `false`, which turned `LoggingService`
  /// into a no-op and dropped the info-and-above JSON lines its file output
  /// exists to keep. What each environment
  /// logs, and where, is decided by `LoggingService`, not by this switch.
  ///
  /// Can be overridden via .env or a dart-define: `ENABLE_LOGGING=false`
  /// turns every output off.
  ///
  /// See also: [enableHttpLogging] for HTTP request/response logging
  static bool get enableLogging {
    if (EnvConfig.has('ENABLE_LOGGING')) {
      return EnvConfig.getBool('ENABLE_LOGGING');
    }
    return true;
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

  // No app version or build number here: they are not configuration. They
  // come from pubspec.yaml's `version:`, which the build stamps into the
  // platform bundle; read them from the platform at runtime. The
  // APP_VERSION / APP_BUILD_NUMBER keys this class used to parse were read
  // by nothing.

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
      if (environmentMisconfigured) {
        debugPrint(
          '  !! ENVIRONMENT MISCONFIGURED: "$environment" is not one of '
          '${knownEnvironments.join(', ')} - the base URL falls back to '
          'localhost and SSL pinning is off',
        );
      }
      debugPrint('Debug Mode: $isDebugMode');
      debugPrint('Release Mode: $isReleaseMode');
      debugPrint('');
      debugPrint('🌐 API Configuration:');
      debugPrint('  Base URL: $baseUrl');
      debugPrint('  Timeout: ${apiTimeout}s');
      debugPrint('  Connect Timeout: ${apiConnectTimeout}s');
      debugPrint('  Receive Timeout: ${apiReceiveTimeout}s');
      debugPrint('  Send Timeout: ${apiSendTimeout}s');
      debugPrint('  SSL Pinning Requested: $enableSslPinning');
      debugPrint('  SSL Pinning Effective: $sslPinningEffective');
      debugPrint('  SSL Fingerprints Configured: ${apiSslFingerprints.length}');
      if (sslPinningMisconfigured) {
        debugPrint(
          '  !! SSL PINNING MISCONFIGURED: requested but no fingerprints '
          'configured - nothing is pinned',
        );
      }
      debugPrint('');
      debugPrint('🚩 Feature Flags:');
      debugPrint('  Logging: $enableLogging');
      debugPrint('  Analytics: $enableAnalytics');
      debugPrint('  Crash Reporting: $enableCrashReporting');
      debugPrint('  Performance Monitoring: $enablePerformanceMonitoring');
      debugPrint('  Debug Features: $enableDebugFeatures');
      debugPrint('  HTTP Logging: $enableHttpLogging');
      debugPrint('═══════════════════════════════════════════════════════════');
    }
  }

  /// Get configuration as a map for debugging
  ///
  /// Returns a map containing all configuration values
  static Map<String, dynamic> getDebugInfo() {
    return {
      'environment': environment,
      'environmentMisconfigured': environmentMisconfigured,
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
      // Requested vs actually enforced - an empty fingerprint list pins
      // nothing even when enableSslPinning is true.
      'enableSslPinning': enableSslPinning,
      'sslPinningEffective': sslPinningEffective,
      'sslPinningMisconfigured': sslPinningMisconfigured,
      'apiSslFingerprintsCount': apiSslFingerprints.length,
      'enableLogging': enableLogging,
      'enableAnalytics': enableAnalytics,
      'enableCrashReporting': enableCrashReporting,
      'enablePerformanceMonitoring': enablePerformanceMonitoring,
      'enableDebugFeatures': enableDebugFeatures,
      'enableHttpLogging': enableHttpLogging,
      'envConfigInitialized': EnvConfig.isInitialized,
    };
  }
}
