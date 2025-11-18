import 'package:dio/dio.dart';

import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';

/// Enhanced interceptor for logging HTTP requests and responses
///
/// This interceptor provides comprehensive logging for API calls including:
/// - Request method, path, headers, query parameters, and body
/// - Response status code, headers, and body
/// - Error details with stack traces
///
/// The interceptor respects the ENABLE_HTTP_LOGGING flag from AppConfig.
class ApiLoggingInterceptor extends Interceptor {
  /// Creates an [ApiLoggingInterceptor] with the given [loggingService]
  ApiLoggingInterceptor({
    required LoggingService loggingService,
  }) : _loggingService = loggingService;

  /// Logging service instance
  final LoggingService _loggingService;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (!AppConfig.enableHttpLogging) {
      super.onRequest(options, handler);
      return;
    }

    final context = <String, dynamic>{
      'method': options.method,
      'path': options.path,
      'baseUrl': options.baseUrl,
      'headers': _sanitizeHeaders(options.headers),
      if (options.queryParameters.isNotEmpty)
        'queryParameters': options.queryParameters,
      if (options.data != null) 'body': _sanitizeBody(options.data),
    };

    _loggingService.debug(
      'API Request: ${options.method} ${options.path}',
      context: context,
    );

    super.onRequest(options, handler);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (!AppConfig.enableHttpLogging) {
      super.onResponse(response, handler);
      return;
    }

    final context = <String, dynamic>{
      'statusCode': response.statusCode,
      'path': response.requestOptions.path,
      'headers': _sanitizeHeaders(response.headers.map),
      if (response.data != null) 'body': _sanitizeBody(response.data),
    };

    // Log as warning for error status codes, info for success
    if (response.statusCode! >= 400) {
      _loggingService.warning(
        'API Response: ${response.statusCode} ${response.requestOptions.path}',
        context: context,
      );
    } else {
      _loggingService.info(
        'API Response: ${response.statusCode} ${response.requestOptions.path}',
        context: context,
      );
    }

    super.onResponse(response, handler);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    if (!AppConfig.enableHttpLogging) {
      super.onError(err, handler);
      return;
    }

    final context = <String, dynamic>{
      'type': err.type.toString(),
      'path': err.requestOptions.path,
      'method': err.requestOptions.method,
      'statusCode': err.response?.statusCode,
      if (err.response?.data != null)
        'responseBody': _sanitizeBody(err.response!.data),
      if (err.requestOptions.data != null)
        'requestBody': _sanitizeBody(err.requestOptions.data),
    };

    _loggingService.error(
      'API Error: ${err.type} ${err.requestOptions.path}',
      context: context,
      error: err,
      stackTrace: err.stackTrace,
    );

    super.onError(err, handler);
  }

  /// Sanitize headers to remove sensitive information
  Map<String, dynamic> _sanitizeHeaders(Map<String, dynamic> headers) {
    final sanitized = Map<String, dynamic>.from(headers);
    const sensitiveKeys = ['authorization', 'cookie', 'x-api-key'];

    for (final key in sensitiveKeys) {
      if (sanitized.containsKey(key)) {
        sanitized[key] = '***REDACTED***';
      }
    }

    return sanitized;
  }

  /// Sanitize request/response body to remove sensitive information
  dynamic _sanitizeBody(dynamic body) {
    if (body == null) return null;

    // If body is a string, try to parse as JSON
    if (body is String) {
      try {
        final json = body;
        return _sanitizeJson(json);
      } on Exception {
        // If parsing fails, return as is (might be form data)
        return body;
      }
    }

    // If body is a Map, sanitize it
    if (body is Map) {
      return _sanitizeJson(body);
    }

    // For other types, return as is
    return body;
  }

  /// Sanitize JSON to remove sensitive fields
  dynamic _sanitizeJson(dynamic json) {
    if (json is Map) {
      final sanitized = <String, dynamic>{};
      const sensitiveKeys = [
        'password',
        'token',
        'accessToken',
        'refreshToken',
        'apiKey',
        'secret',
        'creditCard',
        'cvv',
      ];

      for (final entry in json.entries) {
        final key = entry.key;
        final value = entry.value;
        final keyString = key.toString().toLowerCase();
        final stringKey = key.toString();
        final isSensitive = sensitiveKeys.any(keyString.contains);

        if (isSensitive) {
          sanitized[stringKey] = '***REDACTED***';
        } else if (value is Map) {
          sanitized[stringKey] = _sanitizeJson(value);
        } else if (value is List) {
          sanitized[stringKey] = value.map((item) {
            if (item is Map) {
              return _sanitizeJson(item);
            }
            return item;
          }).toList();
        } else {
          sanitized[stringKey] = value;
        }
      }

      return sanitized;
    }

    return json;
  }
}
