import 'package:dio/dio.dart';
import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';

/// Interceptor for adding authentication tokens to requests
class AuthInterceptor extends Interceptor {
  /// Creates an [AuthInterceptor] with the given [storageService]
  AuthInterceptor(StorageService storageService)
      : _storageService = storageService;

  /// Storage service for retrieving authentication tokens
  final StorageService _storageService;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Get token from storage
    final token = await _storageService.getString(AppConstants.tokenKey);

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
