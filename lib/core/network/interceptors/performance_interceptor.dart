import 'package:dio/dio.dart';
import 'package:flutter_starter/core/performance/i_performance_service.dart';
import 'package:flutter_starter/core/performance/performance_attributes.dart';

/// Interceptor for automatically tracking HTTP request performance
///
/// This interceptor automatically creates performance traces for all HTTP
/// requests made through the API client. It tracks:
/// - Request duration
/// - Response status codes
/// - Success/error metrics
/// - HTTP method and path
///
/// The interceptor respects the ENABLE_PERFORMANCE_MONITORING flag through
/// the [IPerformanceService].
///
/// One trace per logical request. `ApiClient` registers this interceptor just
/// before `ErrorInterceptor`, after `AuthInterceptor` and `RetryInterceptor`,
/// so the trace records how the request finally ended: a 401 that was
/// refreshed and replayed records the replay's 200, not the 401
/// (koniz-dev/flutter-starter#298). A retry re-enters the chain with the same
/// request options and keeps the trace already running, and each trace is
/// stopped at most once.
class PerformanceInterceptor extends Interceptor {
  /// Creates a [PerformanceInterceptor] with the given [performanceService]
  PerformanceInterceptor({required IPerformanceService performanceService})
    : _performanceService = performanceService;

  final IPerformanceService _performanceService;

  /// Traces already stopped, so a request that reaches [onError] twice (a
  /// retry nested inside a retry) records its outcome once.
  final Expando<bool> _stopped = Expando<bool>('performance_trace_stopped');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // A retry of a request already being traced: keep its trace.
    final running = _getTrace(options);
    if (running != null && _stopped[running] != true) {
      super.onRequest(options, handler);
      return;
    }

    // Store trace in request options for use in onResponse/onError
    final trace = _performanceService.startHttpTrace(
      options.method,
      options.path,
    );

    if (trace != null) {
      // Store trace in request options extra for later use
      options.extra['performance_trace'] = trace;
      trace
        ..putAttribute(PerformanceAttributes.httpMethod, options.method)
        ..putAttribute(PerformanceAttributes.httpPath, options.path)
        ..startSync();
    }

    super.onRequest(options, handler);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final trace = _getTrace(response.requestOptions);
    if (trace != null && _stopped[trace] != true) {
      // Record response metrics
      final statusCode = response.statusCode ?? 0;
      trace.putAttribute(
        PerformanceAttributes.httpStatusCode,
        statusCode.toString(),
      );

      // Record success/error based on status code
      if (statusCode >= 200 && statusCode < 300) {
        trace.putMetric(PerformanceMetrics.success, 1);
      } else {
        trace.putMetric(PerformanceMetrics.error, 1);
      }

      // Record response size if available
      if (response.data != null) {
        try {
          final size = _estimateResponseSize(response.data);
          trace.putAttribute(
            PerformanceAttributes.httpResponseSize,
            size.toString(),
          );
        } on Exception {
          // Ignore errors when estimating size
        }
      }

      // Stop the trace
      _stop(trace);
    }

    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final trace = _getTrace(err.requestOptions);
    if (trace != null && _stopped[trace] != true) {
      // Record error metrics
      trace
        ..putMetric(PerformanceMetrics.error, 1)
        ..putAttribute(PerformanceAttributes.errorType, err.type.toString());

      if (err.response != null) {
        final statusCode = err.response!.statusCode ?? 0;
        trace.putAttribute(
          PerformanceAttributes.httpStatusCode,
          statusCode.toString(),
        );
      }

      // Stop the trace
      _stop(trace);
    }

    super.onError(err, handler);
  }

  void _stop(IPerformanceTrace trace) {
    _stopped[trace] = true;
    trace.stopSync();
  }

  /// Get the performance trace from request options
  IPerformanceTrace? _getTrace(RequestOptions options) {
    final trace = options.extra['performance_trace'];
    if (trace is IPerformanceTrace) {
      return trace;
    }
    return null;
  }

  /// Estimate response size in bytes
  int _estimateResponseSize(dynamic data) {
    if (data is String) {
      return data.length * 2; // UTF-16 encoding
    } else if (data is List) {
      return data.length * 100; // Rough estimate
    } else if (data is Map) {
      return data.length * 200; // Rough estimate
    }
    return 0;
  }
}
