import 'package:dio/dio.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/constants/api_endpoints.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/network/interceptors/api_logging_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/cache_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/error_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/logging_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/performance_interceptor.dart';
import 'package:flutter_starter/core/performance/performance_service.dart';
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
  /// [loggingService] - Optional logging service for API logging (if not
  /// provided, uses legacy LoggingInterceptor)
  /// [performanceService] - Optional performance service for automatic HTTP
  /// request tracking
  ApiClient({
    required StorageService storageService,
    required SecureStorageService secureStorageService,
    required AuthInterceptor authInterceptor,
    LoggingService? loggingService,
    PerformanceService? performanceService,
  }) : _dio = _createDio(
          storageService,
          secureStorageService,
          authInterceptor,
          loggingService,
          performanceService,
        );

  static Dio _createDio(
    StorageService storageService,
    SecureStorageService secureStorageService,
    AuthInterceptor authInterceptor,
    LoggingService? loggingService,
    PerformanceService? performanceService,
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

    // Add interceptors - Order matters!
    // ErrorInterceptor must be first to catch all errors
    // PerformanceInterceptor should be early to track all requests
    // CacheInterceptor should be early to intercept requests before network
    // AuthInterceptor handles token injection
    // ApiLoggingInterceptor should be last to log final request/response
    // (falls back to legacy LoggingInterceptor if loggingService is not
    // provided)
    dio.interceptors.addAll([
      ErrorInterceptor(),
      if (performanceService != null)
        PerformanceInterceptor(performanceService: performanceService),
      CacheInterceptor(
        storageService: storageService,
      ),
      authInterceptor,
      if (loggingService != null)
        ApiLoggingInterceptor(loggingService: loggingService)
      else if (AppConfig.enableLogging)
        LoggingInterceptor(), // Legacy interceptor for backward compatibility
    ]);

    return dio;
  }

  final Dio _dio;

  /// Getter for the underlying Dio instance
  Dio get dio => _dio;

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
    try {
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      // Extract domain exception from error interceptor if present
      final error = e.error;
      if (error is AppException) {
        throw error;
      }
      // If not converted by interceptor, rethrow as DioException
      // (should not happen if ErrorInterceptor is properly configured)
      rethrow;
    }
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
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      // Extract domain exception from error interceptor if present
      final error = e.error;
      if (error is AppException) {
        throw error;
      }
      // If not converted by interceptor, rethrow as DioException
      // (should not happen if ErrorInterceptor is properly configured)
      rethrow;
    }
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
    try {
      return await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      // Extract domain exception from error interceptor if present
      final error = e.error;
      if (error is AppException) {
        throw error;
      }
      // If not converted by interceptor, rethrow as DioException
      // (should not happen if ErrorInterceptor is properly configured)
      rethrow;
    }
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
    try {
      return await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      // Extract domain exception from error interceptor if present
      final error = e.error;
      if (error is AppException) {
        throw error;
      }
      // If not converted by interceptor, rethrow as DioException
      // (should not happen if ErrorInterceptor is properly configured)
      rethrow;
    }
  }
}
