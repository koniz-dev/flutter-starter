import 'package:flutter/foundation.dart';

// Compatibility facade keeps legacy API signatures and formatting for now.
// ignore_for_file: directives_ordering, lines_longer_than_80_chars

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/contracts/network_contracts.dart';
import 'package:flutter_starter/core/constants/api_endpoints.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/network/adapters/dio_network_client.dart';
import 'package:flutter_starter/core/network/interceptors/api_logging_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/cache_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/error_interceptor.dart';

import 'package:flutter_starter/core/network/interceptors/performance_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/retry_interceptor.dart';
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
  ApiClient({
    required StorageService storageService,
    required SecureStorageService secureStorageService,
    required AuthInterceptor authInterceptor,
    LoggingService? loggingService,
    IPerformanceService? performanceService,
  }) : _dio = _createDio(
         storageService,
         secureStorageService,
         authInterceptor,
         loggingService,
         performanceService,
       ) {
    _networkClient = DioNetworkClient(_dio);
  }

  static Dio _createDio(
    StorageService storageService,
    SecureStorageService secureStorageService,
    AuthInterceptor authInterceptor,
    LoggingService? loggingService,
    IPerformanceService? performanceService,
  ) {
    final dio = Dio(
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

    // SSL Pinning Configuration
    if (AppConfig.enableSslPinning && AppConfig.apiSslFingerprints.isNotEmpty) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          // Initialize with empty trusted roots to force all connections through badCertificateCallback
          return HttpClient(context: SecurityContext())
            ..badCertificateCallback = (cert, host, port) {
              // Compute SHA-256 fingerprint from the certificate DER
              final certHash = sha256
                  .convert(cert.der)
                  .toString()
                  .replaceAll(':', '')
                  .toLowerCase();
              final isPinned = AppConfig.apiSslFingerprints.contains(certHash);

              if (!isPinned && AppConfig.isDebugMode) {
                debugPrint(
                  'SSL Pinning failure for $host: \n'
                  'Expected one of: ${AppConfig.apiSslFingerprints}\n'
                  'Got: $certHash',
                );
              }
              return isPinned;
            };
        },
      );
    }

    // Add interceptors - Order matters!
    // ErrorInterceptor must be first to catch all errors
    // PerformanceInterceptor should be early to track all requests
    // CacheInterceptor should be early to intercept requests before network
    // AuthInterceptor handles token injection
    // ApiLoggingInterceptor should be last to log final request/response
    // (omitted if loggingService is null)
    dio.interceptors.addAll([
      ErrorInterceptor(),
      if (performanceService != null)
        PerformanceInterceptor(performanceService: performanceService),
      CacheInterceptor(storageService: storageService),
      authInterceptor,
      RetryInterceptor(dio: dio, loggingService: loggingService),
      if (loggingService != null)
        ApiLoggingInterceptor(loggingService: loggingService),
    ]);

    return dio;
  }

  final Dio _dio;
  late final INetworkClient _networkClient;

  /// Getter for the underlying Dio instance
  Dio get dio => _dio;

  /// Getter for transport-agnostic network contract.
  INetworkClient get networkClient => _networkClient;

  /// GET request
  ///
  /// [path] - The endpoint path
  /// [queryParameters] - Optional query parameters
  /// [options] - Optional request options
  /// Returns a [Future] that completes with a [Response]
  /// Throws domain exceptions (ServerException, NetworkException, etc.)
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _sendWithCompatibility(
      NetworkRequest(
        path: path,
        method: NetworkMethod.get,
        queryParameters: queryParameters ?? const <String, dynamic>{},
        headers: _headersFromOptions(options),
      ),
    );
  }

  /// POST request
  ///
  /// [path] - The endpoint path
  /// [data] - Optional request body data
  /// [queryParameters] - Optional query parameters
  /// [options] - Optional request options
  /// Returns a [Future] that completes with a [Response]
  /// Throws domain exceptions (ServerException, NetworkException, etc.)
  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _sendWithCompatibility(
      NetworkRequest(
        path: path,
        method: NetworkMethod.post,
        body: data,
        queryParameters: queryParameters ?? const <String, dynamic>{},
        headers: _headersFromOptions(options),
      ),
    );
  }

  /// PUT request
  ///
  /// [path] - The endpoint path
  /// [data] - Optional request body data
  /// [queryParameters] - Optional query parameters
  /// [options] - Optional request options
  /// Returns a [Future] that completes with a [Response]
  /// Throws domain exceptions (ServerException, NetworkException, etc.)
  Future<Response<dynamic>> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _sendWithCompatibility(
      NetworkRequest(
        path: path,
        method: NetworkMethod.put,
        body: data,
        queryParameters: queryParameters ?? const <String, dynamic>{},
        headers: _headersFromOptions(options),
      ),
    );
  }

  /// DELETE request
  ///
  /// [path] - The endpoint path
  /// [data] - Optional request body data
  /// [queryParameters] - Optional query parameters
  /// [options] - Optional request options
  /// Returns a [Future] that completes with a [Response]
  /// Throws domain exceptions (ServerException, NetworkException, etc.)
  Future<Response<dynamic>> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _sendWithCompatibility(
      NetworkRequest(
        path: path,
        method: NetworkMethod.delete,
        body: data,
        queryParameters: queryParameters ?? const <String, dynamic>{},
        headers: _headersFromOptions(options),
      ),
    );
  }

  Future<Response<dynamic>> _sendWithCompatibility(
    NetworkRequest request,
  ) async {
    try {
      final networkResponse = await _networkClient.send(request);
      return Response<dynamic>(
        requestOptions: RequestOptions(
          path: request.path,
          method: request.method.name,
        ),
        data: networkResponse.data,
        statusCode: networkResponse.statusCode,
        headers: Headers.fromMap(networkResponse.headers),
      );
    } on AppException {
      rethrow;
    } on Exception catch (e) {
      throw NetworkException(e.toString());
    }
  }

  Map<String, String> _headersFromOptions(Options? options) {
    if (options?.headers == null) {
      return const <String, String>{};
    }
    return options!.headers!.map(
      (key, value) => MapEntry(key, value.toString()),
    );
  }
}
