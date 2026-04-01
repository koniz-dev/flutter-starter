import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';

/// Interceptor to automatically retry failed network requests
///
/// Uses an exponential backoff strategy with jitter for transient errors
/// (timeouts, connection errors, and 5xx server errors).
class RetryInterceptor extends Interceptor {
  /// Creates a [RetryInterceptor]
  RetryInterceptor({
    required this.dio,
    this.loggingService,
    this.maxRetries = 3,
    this.initialExecutionDelay = const Duration(seconds: 1),
  });

  /// The Dio instance used for retrying requests
  final Dio dio;

  /// Optional logging service for tracking retry attempts
  final LoggingService? loggingService;

  /// Maximum number of retries per request
  final int maxRetries;

  /// Initial delay before the first retry (will exponentially backoff)
  final Duration initialExecutionDelay;

  final Random _rnd = Random();

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final extra = err.requestOptions.extra;
    var retryCount = extra['retry_count'] as int? ?? 0;

    if (_shouldRetry(err) && retryCount < maxRetries) {
      retryCount++;
      err.requestOptions.extra['retry_count'] = retryCount;

      final delay = _getDelay(retryCount);

      loggingService?.debug(
        'Retrying request [${err.requestOptions.path}] '
        '(attempt $retryCount of $maxRetries) in ${delay.inMilliseconds}ms',
      );

      await Future<void>.delayed(delay);

      try {
        final options = err.requestOptions;

        final response = await dio.request<dynamic>(
          options.path,
          data: options.data,
          queryParameters: options.queryParameters,
          cancelToken: options.cancelToken,
          options: Options(
            method: options.method,
            headers: options.headers,
            responseType: options.responseType,
            contentType: options.contentType,
            validateStatus: options.validateStatus,
            receiveTimeout: options.receiveTimeout,
            sendTimeout: options.sendTimeout,
            extra: options.extra,
          ),
          onReceiveProgress: options.onReceiveProgress,
          onSendProgress: options.onSendProgress,
        );
        return handler.resolve(response);
      } on DioException catch (e) {
        // If the retry also fails it will re-enter the interceptor pipeline
        // via dio.request. But for safety against infinite loops that
        // bypass the extra map, we pass it down. Actually, dio.request
        // above triggers interceptors again from the start, so it will
        // naturally hit RetryInterceptor again with the incremented
        // retryCount. No need to call super.onError here as the new
        // request handles its own interceptors.
        return handler.reject(e);
      }
    }

    return super.onError(err, handler);
  }

  bool _shouldRetry(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }

    if (err.type == DioExceptionType.badResponse) {
      final statusCode = err.response?.statusCode;
      if (statusCode != null && (statusCode >= 500 && statusCode <= 599)) {
        return true;
      }
    }

    return false;
  }

  Duration _getDelay(int retryCount) {
    final jitter = Duration(milliseconds: _rnd.nextInt(500));
    final delay = Duration(
      milliseconds:
          initialExecutionDelay.inMilliseconds * pow(2, retryCount - 1).toInt(),
    );
    return delay + jitter;
  }
}
