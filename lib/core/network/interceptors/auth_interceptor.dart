import 'package:dio/dio.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/constants/api_endpoints.dart';
import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/repositories/auth_repository.dart';

/// Pending request data structure for queuing requests during token refresh
class _PendingRequest {
  _PendingRequest(this.error, this.handler);

  final DioException error;
  final ErrorInterceptorHandler handler;
}

/// Interceptor for adding authentication tokens to requests and handling
/// automatic token refresh on 401 Unauthorized responses
class AuthInterceptor extends Interceptor {
  /// Creates an [AuthInterceptor] with the given dependencies
  AuthInterceptor({
    required SecureStorageService secureStorageService,
    required AuthRepository authRepository,
  }) : _secureStorageService = secureStorageService,
       _authRepository = authRepository;

  /// Secure storage service for retrieving and storing authentication tokens
  final SecureStorageService _secureStorageService;

  /// Auth repository for refreshing tokens
  final AuthRepository _authRepository;

  /// Creates a Dio instance for retrying requests
  /// Uses the same base configuration as the main ApiClient
  Dio _createRetryDio() {
    return Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl + ApiEndpoints.apiVersion,
        connectTimeout: Duration(seconds: AppConfig.apiConnectTimeout),
        receiveTimeout: Duration(seconds: AppConfig.apiReceiveTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
  }

  /// Flag to track if token refresh is in progress
  bool _isRefreshing = false;

  /// Queue of pending requests waiting for token refresh to complete
  final List<_PendingRequest> _pendingRequests = [];

  /// Endpoints that should not trigger token refresh
  static const List<String> _excludedEndpoints = [
    ApiEndpoints.login,
    ApiEndpoints.register,
    ApiEndpoints.refreshToken,
    ApiEndpoints.logout,
  ];

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
      // Check if this endpoint should be excluded from token refresh
      final path = err.requestOptions.path;
      if (_shouldExcludeEndpoint(path)) {
        return super.onError(err, handler);
      }

      return _handle401Error(err, handler);
    }

    super.onError(err, handler);
  }

  /// Checks if the endpoint should be excluded from token refresh
  bool _shouldExcludeEndpoint(String path) {
    return _excludedEndpoints.any((endpoint) => path.contains(endpoint));
  }

  /// Handles 401 Unauthorized errors by attempting token refresh
  Future<void> _handle401Error(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Prevent infinite retry loop
    final requestOptions = err.requestOptions;
    final retryCount = requestOptions.headers['X-Retry-Count'] as String?;
    if (retryCount == '1') {
      // Already retried once, logout user
      await _logoutUser();
      return handler.reject(err);
    }

    // If refresh is already in progress, queue this request
    if (_isRefreshing) {
      return _queueRequest(err, handler);
    }

    // Start token refresh
    _isRefreshing = true;

    try {
      final result = await _authRepository.refreshToken();

      if (result.isSuccess) {
        final newToken = result.dataOrNull;
        if (newToken == null) {
          _isRefreshing = false;
          await _logoutUser();
          return handler.reject(err);
        }

        // Update token in secure storage
        await _secureStorageService.setString(
          AppConstants.tokenKey,
          newToken,
        );

        // Retry original request with new token
        final retryResponse = await _retryRequest(err, newToken);

        // Clear refresh flag and retry pending requests
        _isRefreshing = false;
        await _retryPendingRequests(newToken);

        return handler.resolve(retryResponse);
      } else {
        // Refresh failed, logout user
        _isRefreshing = false;
        await _logoutUser();
        return handler.reject(err);
      }
    } on Exception {
      // Any exception during refresh, logout user
      _isRefreshing = false;
      await _logoutUser();
      handler.reject(err);
    }
  }

  /// Retries the original request with a new token
  Future<Response<dynamic>> _retryRequest(
    DioException err,
    String newToken,
  ) async {
    final requestOptions = err.requestOptions;

    // Create new request options with updated headers
    final newOptions = requestOptions.copyWith(
      headers: {
        ...requestOptions.headers,
        'Authorization': 'Bearer $newToken',
        'X-Retry-Count': '1',
      },
    );

    // Retry the request using a new Dio instance
    final retryDio = _createRetryDio();
    return retryDio.request(
      newOptions.path,
      data: newOptions.data,
      queryParameters: newOptions.queryParameters,
      options: Options(
        method: newOptions.method,
        headers: newOptions.headers,
        contentType: newOptions.contentType,
        responseType: newOptions.responseType,
        followRedirects: newOptions.followRedirects,
        maxRedirects: newOptions.maxRedirects,
        validateStatus: newOptions.validateStatus,
        receiveTimeout: newOptions.receiveTimeout,
        sendTimeout: newOptions.sendTimeout,
      ),
    );
  }

  /// Queues a request to be retried after token refresh completes
  void _queueRequest(DioException err, ErrorInterceptorHandler handler) {
    _pendingRequests.add(_PendingRequest(err, handler));
  }

  /// Retries all pending requests with the new token
  Future<void> _retryPendingRequests(String newToken) async {
    final requests = List<_PendingRequest>.from(_pendingRequests);
    _pendingRequests.clear();

    for (final pending in requests) {
      try {
        final retryResponse = await _retryRequest(pending.error, newToken);
        pending.handler.resolve(retryResponse);
      } on Exception catch (e) {
        // If retry fails, reject the pending request
        final dioException = DioException(
          requestOptions: pending.error.requestOptions,
          error: e,
          response: pending.error.response,
          type: pending.error.type,
        );
        pending.handler.reject(dioException);
      }
    }
  }

  /// Logs out the user by clearing all authentication data
  Future<void> _logoutUser() async {
    // Clear tokens from secure storage
    await _secureStorageService.remove(AppConstants.tokenKey);
    await _secureStorageService.remove(AppConstants.refreshTokenKey);

    // Note: User data is cleared via AuthRepository.logout() if needed
    // This is a minimal cleanup for the interceptor
  }
}
