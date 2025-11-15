import 'package:dio/dio.dart';
import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';

/// Interceptor for adding authentication tokens to requests
class AuthInterceptor extends Interceptor {
  /// Creates an [AuthInterceptor] with the given [secureStorageService]
  AuthInterceptor(SecureStorageService secureStorageService)
      : _secureStorageService = secureStorageService;

  /// Secure storage service for retrieving authentication tokens
  final SecureStorageService _secureStorageService;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Get token from secure storage
    final token = await _secureStorageService.getString(AppConstants.tokenKey);

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    super.onRequest(options, handler);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Handle 401 Unauthorized - refresh token or logout
    if (err.response?.statusCode == 401) {
      // Implement token refresh logic here
      // For now, just pass the error
    }

    super.onError(err, handler);
  }
}
