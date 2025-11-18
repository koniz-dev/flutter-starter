import 'package:flutter_starter/core/config/app_config.dart';

/// Application-wide constants
///
/// Contains only application constants that are not configuration.
/// For configuration values (timeouts, URLs, etc.), use [AppConfig].
/// For app version, use [AppConfig.appVersion].
class AppConstants {
  AppConstants._();

  /// Application name displayed to users
  static const String appName = 'Flutter Starter';

  /// Default number of items per page for pagination
  static const int defaultPageSize = 20;

  /// Maximum number of items per page for pagination
  static const int maxPageSize = 100;

  /// Storage key for authentication access token
  static const String tokenKey = 'auth_token';

  /// Storage key for authentication refresh token
  static const String refreshTokenKey = 'refresh_token';

  /// Storage key for cached user data
  static const String userDataKey = 'user_data';

  /// Storage key for user's theme preference (light/dark/system)
  static const String themeKey = 'theme_mode';

  /// Storage key for user's language preference
  static const String languageKey = 'language';
}
