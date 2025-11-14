/// Application-wide constants
class AppConstants {
  AppConstants._();

  /// Application name displayed to users
  static const String appName = 'Flutter Starter';

  /// Current application version
  static const String appVersion = '1.0.0';

  /// Network connection timeout duration
  static const Duration connectionTimeout = Duration(seconds: 30);

  /// Network receive timeout duration
  static const Duration receiveTimeout = Duration(seconds: 30);

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
