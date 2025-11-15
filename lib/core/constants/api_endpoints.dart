import 'package:flutter_starter/core/config/app_config.dart';

/// API endpoints constants
///
/// Contains only endpoint path constants.
/// For base URL configuration, use [AppConfig.baseUrl].
class ApiEndpoints {
  ApiEndpoints._();

  /// API version prefix for all endpoints
  static const String apiVersion = '/v1';

  /// Authentication endpoint for user login
  static const String login = '/auth/login';

  /// Authentication endpoint for user registration
  static const String register = '/auth/register';

  /// Authentication endpoint for user logout
  static const String logout = '/auth/logout';

  /// Authentication endpoint for refreshing access token
  static const String refreshToken = '/auth/refresh';

  /// User endpoint for retrieving user profile
  static const String userProfile = '/user/profile';

  /// User endpoint for updating user profile
  static const String updateProfile = '/user/profile';
}
