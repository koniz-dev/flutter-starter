// Transport facade. Its public request surface is typed entirely on
// `lib/core/contracts/network_contracts.dart`, so a caller can hold an
// ApiClient without importing `package:dio`.
// ignore_for_file: directives_ordering

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/contracts/network_contracts.dart';
import 'package:flutter_starter/core/constants/api_endpoints.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/network/adapters/dio_network_client.dart';
import 'package:flutter_starter/core/network/request_cancellation.dart';
import 'package:flutter_starter/core/network/interceptors/api_logging_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/cache_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/error_interceptor.dart';

import 'package:flutter_starter/core/network/interceptors/performance_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/retry_interceptor.dart';
import 'package:flutter_starter/core/network/ssl_pinning.dart';
import 'package:flutter_starter/core/performance/i_performance_service.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';

/// API client for making HTTP requests
class ApiClient {
  /// Creates an instance of [ApiClient] with configured Dio instance
  ///
  /// [storageService] - Storage service for non-sensitive data
  /// [secureStorageService] - Secure storage service for authentication
  /// tokens
  /// [authInterceptor] - Auth interceptor for token management and refresh
  /// [loggingService] - Optional logging service; when set, adds
  /// [ApiLoggingInterceptor] for HTTP logging.
  /// [performanceService] - Optional performance service for automatic HTTP
  /// request tracking
  /// [sslPinning] - Certificate pinning policy; defaults to
  /// [SslPinning.fromConfig] (`ENABLE_SSL_PINNING` / `API_SSL_FINGERPRINTS`)
  /// [cacheConfig] - `CacheInterceptor` freshness policy; defaults to
  /// [CacheConfig]'s one hour fresh, seven days as a fallback
  /// [retryInitialDelay] and [retryMaxJitter] - Override
  /// [RetryInterceptor]'s backoff, so a test that walks the retry path does
  /// not sleep through it
  ApiClient({
    required StorageService storageService,
    required SecureStorageService secureStorageService,
    required AuthInterceptor authInterceptor,
    LoggingService? loggingService,
    IPerformanceService? performanceService,
    SslPinning? sslPinning,
    CacheConfig? cacheConfig,
    @visibleForTesting Duration? retryInitialDelay,
    @visibleForTesting Duration? retryMaxJitter,
  }) : _dio = _createDio(
         storageService,
         secureStorageService,
         authInterceptor,
         loggingService,
         performanceService,
         sslPinning ?? SslPinning.fromConfig(),
         cacheConfig,
         retryInitialDelay,
         retryMaxJitter,
       ) {
    _networkClient = DioNetworkClient(
      _dio,
      deadline: Duration(seconds: AppConfig.apiTimeout),
    );
    _cacheInterceptor = _dio.interceptors.whereType<CacheInterceptor>().single;
  }

  static Dio _createDio(
    StorageService storageService,
    SecureStorageService secureStorageService,
    AuthInterceptor authInterceptor,
    LoggingService? loggingService,
    IPerformanceService? performanceService,
    SslPinning sslPinning,
    CacheConfig? cacheConfig,
    Duration? retryInitialDelay,
    Duration? retryMaxJitter,
  ) {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl + ApiEndpoints.apiVersion,
        connectTimeout: Duration(seconds: AppConfig.apiConnectTimeout),
        receiveTimeout: Duration(seconds: AppConfig.apiReceiveTimeout),
        sendTimeout: Duration(seconds: AppConfig.apiSendTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // SSL Pinning Configuration.
    //
    // Returns null when pinning is off; when it is requested without
    // fingerprints, SslPinning logs and asserts instead of degrading quietly.
    final pinnedAdapter = sslPinning.createAdapter();
    if (pinnedAdapter != null) {
      dio.httpClientAdapter = pinnedAdapter;
    }

    // Let the 401 replay client borrow this transport, so a retry carrying a
    // freshly minted access token goes through the same pinned adapter
    // instead of a bare, system-trust-store Dio.
    authInterceptor.attachTransport(dio);

    // Shares AuthInterceptor's token store on purpose: the cache must know
    // whether a credential exists, and it cannot learn that from the request
    // headers, which AuthInterceptor only writes at its own position in the
    // chain. See CacheInterceptor's class doc.
    final cacheInterceptor = CacheInterceptor(
      storageService: storageService,
      tokenStore: authInterceptor.tokenStore,
      cacheConfig: cacheConfig,
    );

    // A forced logout (401 whose refresh fails) has to empty the same cache
    // `AuthRepositoryImpl.logout()` empties, or the session boundary the user
    // did not choose leaves cached bodies behind.
    authInterceptor.attachResponseCache(cacheInterceptor);

    // Add interceptors - Order matters!
    //
    // dio runs `onRequest` in list order AND `onError` in list order (see
    // `dio_mixin.dart`: both loops iterate `interceptors` forwards). An
    // `onError` that calls `handler.reject(...)` terminates the error chain,
    // so every interceptor registered after it never sees the error.
    // ErrorInterceptor does exactly that, therefore it must be registered
    // LAST - registering it first silently disabled retry, 401 token refresh,
    // performance trace teardown and error logging.
    //
    // CacheInterceptor should be early to intercept requests before network
    // AuthInterceptor handles token injection and 401 refresh
    // RetryInterceptor retries transient failures (timeouts, 5xx)
    // ApiLoggingInterceptor logs a redacted stand-in for the DioException
    // (omitted if loggingService is null)
    // PerformanceInterceptor sits after Auth and Retry so its trace records
    // how the request finally ended - a refreshed-and-replayed 401 is the
    // replay's 200, not a failed 401
    // (omitted if performanceService is null)
    // ErrorInterceptor converts whatever survives into a domain exception
    dio.interceptors.addAll([
      cacheInterceptor,
      authInterceptor,
      RetryInterceptor(
        dio: dio,
        loggingService: loggingService,
        initialExecutionDelay: retryInitialDelay ?? const Duration(seconds: 1),
        maxJitter: retryMaxJitter ?? const Duration(milliseconds: 500),
      ),
      if (loggingService != null)
        ApiLoggingInterceptor(loggingService: loggingService),
      if (performanceService != null)
        PerformanceInterceptor(performanceService: performanceService),
      ErrorInterceptor(),
    ]);

    return dio;
  }

  final Dio _dio;
  late final DioNetworkClient _networkClient;
  late final CacheInterceptor _cacheInterceptor;

  /// Escape hatch onto the underlying Dio instance.
  ///
  /// Deliberately kept, and deliberately not on any request path. No verb on
  /// this class accepts or returns a dio type, so reaching for
  /// `.dio` is an explicit opt-out of [INetworkClient] rather than something
  /// an ordinary `post()` forces on the caller. Use it for transport-level
  /// concerns only - swapping [Dio.httpClientAdapter], inspecting
  /// [Dio.interceptors], reading [BaseOptions]. Typing a data source on what
  /// it returns puts `package:dio` back in the feature layer, which is the
  /// leak the typed verbs closed.
  Dio get dio => _dio;

  /// Getter for transport-agnostic network contract.
  INetworkClient get networkClient => _networkClient;

  /// The locally persisted HTTP response cache installed on this client.
  ///
  /// Session teardown calls `clearCache()` on it so cached bodies do not
  /// survive a logout.
  IHttpResponseCache get responseCache => _cacheInterceptor;

  /// GET request
  ///
  /// [path] - The endpoint path
  /// [queryParameters] - Optional query parameters
  /// [headers] - Optional per-request headers
  /// [cancellation] - Optional handle that cancels the request
  /// Returns a [Future] that completes with a [NetworkResponse]
  /// Throws domain exceptions (ServerException, NetworkException, etc.)
  Future<NetworkResponse<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    RequestCancellation? cancellation,
  }) async {
    return await _send(
      cancellation: cancellation,
      NetworkRequest(
        path: path,
        method: NetworkMethod.get,
        queryParameters: queryParameters ?? const <String, dynamic>{},
        headers: headers ?? const <String, String>{},
      ),
    );
  }

  /// POST request
  ///
  /// [path] - The endpoint path
  /// [data] - Optional request body data
  /// [queryParameters] - Optional query parameters
  /// [headers] - Optional per-request headers
  /// [cancellation] - Optional handle that cancels the request
  /// Returns a [Future] that completes with a [NetworkResponse]
  /// Throws domain exceptions (ServerException, NetworkException, etc.)
  Future<NetworkResponse<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    RequestCancellation? cancellation,
  }) async {
    return await _send(
      cancellation: cancellation,
      NetworkRequest(
        path: path,
        method: NetworkMethod.post,
        body: data,
        queryParameters: queryParameters ?? const <String, dynamic>{},
        headers: headers ?? const <String, String>{},
      ),
    );
  }

  /// PUT request
  ///
  /// [path] - The endpoint path
  /// [data] - Optional request body data
  /// [queryParameters] - Optional query parameters
  /// [headers] - Optional per-request headers
  /// [cancellation] - Optional handle that cancels the request
  /// Returns a [Future] that completes with a [NetworkResponse]
  /// Throws domain exceptions (ServerException, NetworkException, etc.)
  Future<NetworkResponse<dynamic>> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    RequestCancellation? cancellation,
  }) async {
    return await _send(
      cancellation: cancellation,
      NetworkRequest(
        path: path,
        method: NetworkMethod.put,
        body: data,
        queryParameters: queryParameters ?? const <String, dynamic>{},
        headers: headers ?? const <String, String>{},
      ),
    );
  }

  /// PATCH request
  ///
  /// [path] - The endpoint path
  /// [data] - Optional request body data
  /// [queryParameters] - Optional query parameters
  /// [headers] - Optional per-request headers
  /// [cancellation] - Optional handle that cancels the request
  /// Returns a [Future] that completes with a [NetworkResponse]
  /// Throws domain exceptions (ServerException, NetworkException, etc.)
  Future<NetworkResponse<dynamic>> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    RequestCancellation? cancellation,
  }) async {
    return await _send(
      cancellation: cancellation,
      NetworkRequest(
        path: path,
        method: NetworkMethod.patch,
        body: data,
        queryParameters: queryParameters ?? const <String, dynamic>{},
        headers: headers ?? const <String, String>{},
      ),
    );
  }

  /// DELETE request
  ///
  /// [path] - The endpoint path
  /// [data] - Optional request body data
  /// [queryParameters] - Optional query parameters
  /// [headers] - Optional per-request headers
  /// [cancellation] - Optional handle that cancels the request
  /// Returns a [Future] that completes with a [NetworkResponse]
  /// Throws domain exceptions (ServerException, NetworkException, etc.)
  Future<NetworkResponse<dynamic>> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    RequestCancellation? cancellation,
  }) async {
    return await _send(
      cancellation: cancellation,
      NetworkRequest(
        path: path,
        method: NetworkMethod.delete,
        body: data,
        queryParameters: queryParameters ?? const <String, dynamic>{},
        headers: headers ?? const <String, String>{},
      ),
    );
  }

  Future<NetworkResponse<dynamic>> _send(
    NetworkRequest request, {
    RequestCancellation? cancellation,
  }) async {
    try {
      return await _networkClient.send(request, cancellation: cancellation);
    } on AppException {
      rethrow;
    } on Exception catch (e) {
      throw NetworkException(e.toString());
    }
  }
}
