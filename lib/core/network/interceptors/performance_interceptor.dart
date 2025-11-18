import 'package:dio/dio.dart';
import 'package:flutter_starter/core/performance/performance_attributes.dart';
import 'package:flutter_starter/core/performance/performance_service.dart';

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
/// the PerformanceService.
class PerformanceInterceptor extends Interceptor {
  /// Creates a [PerformanceInterceptor] with the given [performanceService]
  PerformanceInterceptor({
    required PerformanceService performanceService,
  }) : _performanceService = performanceService;

  final PerformanceService _performanceService;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    // Store trace in request options for use in onResponse/onError
    final trace = _performanceService.startHttpTrace(
      options.method,
      options.path,
    );

    if (trace != null) {
      // Store trace in request options extra for later use
      options.extra['performance_trace'] = trace;
      trace
        ..putAttribute(
          PerformanceAttributes.httpMethod,
          options.method,
        )
        ..putAttribute(
          PerformanceAttributes.httpPath,
          options.path,
        )
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
    if (trace != null) {
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
      trace.stopSync();
    }

    super.onResponse(response, handler);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    final trace = _getTrace(err.requestOptions);
    if (trace != null) {
      // Record error metrics
      trace
        ..putMetric(PerformanceMetrics.error, 1)
        ..putAttribute(
          PerformanceAttributes.errorType,
          err.type.toString(),
        );

      if (err.response != null) {
        final statusCode = err.response!.statusCode ?? 0;
        trace.putAttribute(
          PerformanceAttributes.httpStatusCode,
          statusCode.toString(),
        );
      }

      // Stop the trace
      trace.stopSync();
    }

    super.onError(err, handler);
  }

  /// Get the performance trace from request options
  PerformanceTrace? _getTrace(RequestOptions options) {
    final trace = options.extra['performance_trace'];
    if (trace is PerformanceTrace) {
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
