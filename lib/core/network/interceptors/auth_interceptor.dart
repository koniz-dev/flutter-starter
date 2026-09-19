// Constructor preserves backward-compatible parameter ordering/signature.
// ignore_for_file: always_put_required_named_parameters_first, lines_longer_than_80_chars

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/constants/api_endpoints.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/network/adapters/shared_transport_adapter.dart';
import 'package:flutter_starter/core/network/ssl_pinning.dart';
import 'package:flutter_starter/core/storage/adapters/secure_token_store.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';

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
    ITokenStore? tokenStore,
    SecureStorageService? secureStorageService,
    required Future<Result<String>> Function() refreshToken,
    Dio Function()? retryDioFactory,
  }) : _retryDioFactory = retryDioFactory,
       _tokenStore =
           tokenStore ??
           (secureStorageService != null
               ? SecureTokenStore(secureStorageService)
               : throw ArgumentError(
                   'Either tokenStore or secureStorageService must be provided.',
                 )),
       _refreshToken = refreshToken;

  /// Token storage for retrieving and storing authentication tokens
  final ITokenStore _tokenStore;

  /// Callback to refresh the access token.
  ///
  /// Intentionally a callback (instead of depending on a repository/provider)
  /// to avoid DI cycles during app bootstrap.
  final Future<Result<String>> Function() _refreshToken;

  /// Optional factory for the Dio instance used to replay the original
  /// request after a successful refresh.
  ///
  /// Production leaves this null: the replay client is built once and borrows
  /// the transport of the client this interceptor is attached to (see
  /// [attachTransport]), so the replay cannot re-enter this interceptor but
  /// still goes through the pinned adapter. Tests inject a factory to point
  /// the replay at a fake [HttpClientAdapter].
  final Dio Function()? _retryDioFactory;

  /// The client this interceptor is installed on, if any.
  ///
  /// Only its transport and base options are borrowed - never its interceptor
  /// chain, which would re-enter this interceptor on every replay.
  Dio? _hostDio;

  /// Single replay client, created on first use and reused afterwards.
  Dio? _retryDio;

  /// Binds this interceptor to the client it is installed on.
  ///
  /// Called by `ApiClient` after the transport (including certificate
  /// pinning) is configured, so replayed requests use the same adapter
  /// instead of a fresh, unpinned one.
  void attachTransport(Dio dio) {
    _hostDio = dio;
    // Drop any replay client built against the previous transport.
    _closeRetryDio();
  }

  /// Returns the single replay client, creating it on first use.
  Dio retryDio() {
    final existing = _retryDio;
    if (existing != null) {
      return existing;
    }

    final factory = _retryDioFactory;
    final created = factory != null ? factory() : _buildRetryDio();
    _retryDio = created;
    return created;
  }

  Dio _buildRetryDio() {
    final host = _hostDio;
    final dio = Dio(
      BaseOptions(
        baseUrl:
            host?.options.baseUrl ??
            AppConfig.baseUrl + ApiEndpoints.apiVersion,
        connectTimeout:
            host?.options.connectTimeout ??
            Duration(seconds: AppConfig.apiConnectTimeout),
        receiveTimeout:
            host?.options.receiveTimeout ??
            Duration(seconds: AppConfig.apiReceiveTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    if (host != null) {
      // Borrow the host transport so pinning applies to the replay too.
      dio.httpClientAdapter = SharedTransportAdapter(
        () => host.httpClientAdapter,
      );
    } else {
      // Not attached to a client (standalone use): pin the replay directly.
      final pinned = SslPinning.fromConfig().createAdapter();
      if (pinned != null) {
        dio.httpClientAdapter = pinned;
      }
    }

    return dio;
  }

  void _closeRetryDio() {
    _retryDio?.close(force: true);
    _retryDio = null;
  }

  /// Releases the replay client and its connection pool.
  ///
  /// Wired to provider disposal; safe to call more than once.
  void dispose() => _closeRetryDio();

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
    final token = await _tokenStore.getAccessToken();

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
  ///
  /// Every exit path completes both this request's handler and every queued
  /// handler: a handler that is neither resolved nor rejected leaves its
  /// caller awaiting a future that never finishes.
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
    String? refreshedToken;

    try {
      final result = await _refreshToken();
      final newToken = result.isSuccess ? result.dataOrNull : null;

      if (newToken == null) {
        // Refresh failed (or returned nothing usable), logout user
        await _logoutUser();
        handler.reject(err);
        return;
      }

      // Update token in secure storage
      await _tokenStore.setAccessToken(newToken);
      refreshedToken = newToken;

      // Retry original request with new token
      final retryResponse = await _retryRequest(err, newToken);
      handler.resolve(retryResponse);
    }
    // Catches Error as well as Exception on purpose: a TypeError thrown while
    // parsing a malformed refresh response used to escape, leaving
    // _isRefreshing stuck true and every later 401 queued forever.
    on Object catch (e) {
      refreshedToken = null;
      await _logoutUser();
      handler.reject(_asDioException(err, e));
    } finally {
      // Reset before draining: a 401 arriving during the drain must be able
      // to start a fresh refresh rather than queue behind a finished one.
      _isRefreshing = false;
      await _drainPendingRequests(refreshedToken);
    }
  }

  /// Wraps a non-Dio failure so the caller still gets a [DioException].
  DioException _asDioException(DioException original, Object error) {
    if (error is DioException) {
      return error;
    }
    return DioException(
      requestOptions: original.requestOptions,
      error: error,
      response: original.response,
      type: original.type,
    );
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

    // Replay through the shared retry client so the transport - and its
    // certificate pinning - matches the original request.
    return retryDio().request(
      newOptions.path,
      data: newOptions.data,
      queryParameters: newOptions.queryParameters,
      // Cancelling the original request must abort the replay too.
      cancelToken: requestOptions.cancelToken,
      onSendProgress: requestOptions.onSendProgress,
      onReceiveProgress: requestOptions.onReceiveProgress,
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

  /// Completes every queued request.
  ///
  /// With a [newToken] each one is replayed and resolved (or rejected if the
  /// replay fails). Without one the refresh failed, so each queued handler is
  /// rejected with its own original error - never left dangling.
  Future<void> _drainPendingRequests(String? newToken) async {
    if (_pendingRequests.isEmpty) {
      return;
    }

    final requests = List<_PendingRequest>.from(_pendingRequests);
    _pendingRequests.clear();

    for (final pending in requests) {
      if (newToken == null) {
        pending.handler.reject(pending.error);
        continue;
      }

      try {
        final retryResponse = await _retryRequest(pending.error, newToken);
        pending.handler.resolve(retryResponse);
      } on Object catch (e) {
        // If retry fails, reject the pending request
        pending.handler.reject(_asDioException(pending.error, e));
      }
    }
  }

  /// Logs out the user by clearing all authentication data
  Future<void> _logoutUser() async {
    // Clear tokens from secure storage
    try {
      await _tokenStore.clearAllTokens();
    } on Object catch (_) {
      // Never let cleanup failure stop a handler from being completed.
    }

    // Note: User data is cleared via AuthRepository.logout() if needed
    // This is a minimal cleanup for the interceptor
  }
}
