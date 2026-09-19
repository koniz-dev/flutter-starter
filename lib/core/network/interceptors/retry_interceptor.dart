import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';

/// Interceptor to automatically retry failed network requests
///
/// Uses an exponential backoff strategy with jitter for transient errors
/// (timeouts, connection errors, and 5xx server errors).
///
/// ## Which requests are replayed
///
/// Replaying a request the server may already have processed turns one user
/// action into several server-side writes, so the HTTP method is part of the
/// decision:
///
/// * **Safe methods** ([safeMethods]: `GET`, `HEAD`, `OPTIONS`; RFC 9110
///   section 9.2.1) have no server-side effect, so an extra attempt costs
///   nothing. They are retried on every transient error type.
/// * **Everything else** (`POST`, `PUT`, `PATCH`, `DELETE`, ...) is retried
///   only on [DioExceptionType.connectionTimeout] - the one dio error type
///   that proves no request byte reached the server, because the socket never
///   finished connecting. A `sendTimeout`, a `receiveTimeout`, a
///   `connectionError` (a socket can also be reset *after* the body was sent)
///   or a 5xx from an intermediary all leave open the possibility that the
///   write was committed upstream.
///
/// `PUT` and `DELETE` are idempotent but not safe, so they are not replayed by
/// default either: idempotency promises only that the server-side *state* is
/// unchanged by a repeat, not that the repeat is harmless - a replayed
/// `DELETE` answers 404 and a replayed `PUT` can clobber a concurrent write.
/// Opt those in per request when the endpoint really is replay-safe.
///
/// ## Per-request override
///
/// Two equivalent, explicit, per-request opt-ins exist, both off by default:
///
/// ```dart
/// // Wherever a raw Dio call is available:
/// dio.post('/orders', data: body, options: Options(extra: {'retry': true}));
///
/// // Through ApiClient, whose facade forwards headers but not `extra`:
/// apiClient.post(
///   '/orders',
///   data: body,
///   options: Options(headers: {'Idempotency-Key': key}),
/// );
/// ```
///
/// `extra: {'retry': false}` is the mirror image and suppresses retry even for
/// a safe method. An override only decides whether *this request* may be
/// replayed; the error-type and [maxRetries] gates still apply.
class RetryInterceptor extends Interceptor {
  /// Creates a [RetryInterceptor]
  RetryInterceptor({
    required this.dio,
    this.loggingService,
    this.maxRetries = 3,
    this.initialExecutionDelay = const Duration(seconds: 1),
  });

  /// HTTP methods replayed automatically on any transient error.
  ///
  /// The *safe* methods of RFC 9110 section 9.2.1: read-only, so an extra
  /// attempt cannot duplicate a server-side effect.
  static const Set<String> safeMethods = {'GET', 'HEAD', 'OPTIONS'};

  /// `RequestOptions.extra` key carrying the per-request override.
  ///
  /// `true` allows replaying an otherwise non-replayable request; `false`
  /// suppresses replay entirely. Absent means "decide from the method".
  static const String retryExtraKey = 'retry';

  /// Request header that opts a non-safe request into replay.
  ///
  /// Sending an idempotency key is the caller telling the server to
  /// de-duplicate, which is precisely what makes a replay safe. Matched
  /// case-insensitively; an empty value does not opt in.
  static const String idempotencyKeyHeader = 'Idempotency-Key';

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
    final options = err.requestOptions;
    final override = _replayOverride(options);

    if (override == false) {
      return false;
    }

    final replayable =
        override ?? safeMethods.contains(options.method.toUpperCase());

    if (!replayable) {
      // The request may have been received and committed by the server, so a
      // replay is only safe when the failure proves it never got there.
      // connectionTimeout is the only dio error type carrying that proof.
      return err.type == DioExceptionType.connectionTimeout;
    }

    return _isTransient(err);
  }

  /// Per-request opt-in/opt-out, or null when the caller said nothing.
  bool? _replayOverride(RequestOptions options) {
    final flag = options.extra[retryExtraKey];
    if (flag is bool) {
      return flag;
    }

    for (final entry in options.headers.entries) {
      if (entry.key.toLowerCase() == idempotencyKeyHeader.toLowerCase()) {
        final value = entry.value?.toString() ?? '';
        if (value.isNotEmpty) {
          return true;
        }
      }
    }

    return null;
  }

  bool _isTransient(DioException err) {
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
