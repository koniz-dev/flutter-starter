import 'package:dio/dio.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';

/// Mapper for converting DioException to domain exceptions
class DioExceptionMapper {
  /// Converts a [DioException] to an appropriate domain exception
  ///
  /// Maps different DioException types to domain exceptions:
  /// - Connection/timeout errors (including transformTimeout) → NetworkException
  /// - Bad response (4xx, 5xx) → ServerException
  /// - Other errors → NetworkException
  static AppException map(DioException exception) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
        return NetworkException(
          'Connection timeout: ${exception.message ?? 'Request timed out'}',
          code: 'CONNECTION_TIMEOUT',
        );

      case DioExceptionType.sendTimeout:
        return NetworkException(
          'Send timeout: ${exception.message ?? 'Request send timed out'}',
          code: 'SEND_TIMEOUT',
        );

      case DioExceptionType.receiveTimeout:
        return NetworkException(
          'Receive timeout: '
          '${exception.message ?? 'Response receive timed out'}',
          code: 'RECEIVE_TIMEOUT',
        );

      // The server answered, but decoding the body locally (for example a
      // large JSON payload) took longer than RequestOptions.transformTimeout.
      // The data never reached the app, so it is reported like the other
      // client-side timeouts rather than as a server error.
      case DioExceptionType.transformTimeout:
        return NetworkException(
          'Transform timeout: '
          '${exception.message ?? 'Response processing timed out'}',
          code: 'TRANSFORM_TIMEOUT',
        );

      case DioExceptionType.badResponse:
        return ServerException(
          _extractErrorMessage(exception),
          statusCode: exception.response?.statusCode,
          code: _extractErrorCode(exception),
        );

      case DioExceptionType.cancel:
        return NetworkException(
          'Request cancelled: ${exception.message ?? 'Request was cancelled'}',
          code: 'REQUEST_CANCELLED',
        );

      case DioExceptionType.connectionError:
        return NetworkException(
          'Connection error: '
          '${exception.message ?? 'Unable to connect to server'}',
          code: 'CONNECTION_ERROR',
        );

      case DioExceptionType.badCertificate:
        return NetworkException(
          'Bad certificate: ${exception.message ?? 'SSL certificate error'}',
          code: 'BAD_CERTIFICATE',
        );

      case DioExceptionType.unknown:
        // Check if it's actually a network error
        if ((exception.message?.contains('SocketException') ?? false) ||
            (exception.message?.contains('Network is unreachable') ?? false)) {
          return NetworkException(
            'Network error: '
            '${exception.message ?? 'Unable to connect to network'}',
            code: 'NETWORK_ERROR',
          );
        }
        // Default to network exception for unknown errors
        return NetworkException(
          'Network error: '
          '${exception.message ?? 'An unexpected network error occurred'}',
          code: 'UNKNOWN_NETWORK_ERROR',
        );
    }
  }

  /// Extracts error message from DioException response
  ///
  /// Tries to extract user-friendly error message from response data.
  /// Falls back to status code-based messages or default message.
  static String _extractErrorMessage(DioException exception) {
    final response = exception.response;
    if (response == null) {
      return _getDefaultMessageForStatusCode(null);
    }

    final statusCode = response.statusCode;
    final data = response.data;

    // Try to extract message from response data
    if (data != null) {
      if (data is Map<String, dynamic>) {
        // Try nested error object first (before trying error as string)
        final error = data['error'];
        if (error is Map<String, dynamic>) {
          final nestedMessage =
              _messageText(error['message']) ?? _messageText(error['error']);
          if (nestedMessage != null) {
            return nestedMessage;
          }
        }

        // Try common error message fields
        final message =
            _messageText(data['message']) ??
            _messageText(error is Map ? null : error) ??
            _messageText(data['error_message']) ??
            _messageText(data['msg']);

        if (message != null && message.isNotEmpty) {
          return message;
        }
      } else if (data is String && data.isNotEmpty) {
        return data;
      }
    }

    // Fall back to status code-based message
    return _getDefaultMessageForStatusCode(statusCode);
  }

  /// Extracts error code from DioException response
  ///
  /// Tries to extract error code from response data.
  /// Falls back to status code-based code or null.
  static String? _extractErrorCode(DioException exception) {
    final response = exception.response;
    if (response == null) return null;

    final data = response.data;
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      // Try common error code fields, then the nested error object
      return _codeText(data['code']) ??
          _codeText(data['error_code']) ??
          _codeText(data['errorCode']) ??
          (error is Map<String, dynamic>
              ? _codeText(error['code']) ?? _codeText(error['error_code'])
              : null);
    }

    return null;
  }

  /// A readable message from one body field, or null when it holds none.
  ///
  /// Never throws: a body is whatever the server sent. The fields used to be
  /// read with `as String?`, so NestJS's default validation body - whose
  /// `message` is a list - threw a `TypeError` inside `ErrorInterceptor`, and
  /// the caller got `NetworkError(code: unknown)` instead of the 400.
  /// A list is joined with `; `, numbers
  /// and booleans are printed, and anything else (a map) is skipped.
  static String? _messageText(Object? value) {
    final text = switch (value) {
      final String s => s.trim(),
      final List<Object?> items =>
        items.map(_messageText).whereType<String>().join('; '),
      final num n => '$n',
      final bool b => '$b',
      _ => null,
    };
    return text == null || text.isEmpty ? null : text;
  }

  /// An error code from one body field: a String as is, a number printed.
  ///
  /// `{"code": 1001}` used to throw for the same reason as a list message.
  static String? _codeText(Object? value) {
    final text = switch (value) {
      final String s => s.trim(),
      final num n => '$n',
      _ => null,
    };
    return text == null || text.isEmpty ? null : text;
  }

  /// Gets default error message based on HTTP status code
  static String _getDefaultMessageForStatusCode(int? statusCode) {
    if (statusCode == null) {
      return 'An unexpected error occurred';
    }

    switch (statusCode) {
      case 400:
        return 'Bad request. Please check your input.';
      case 401:
        return 'Unauthorized. Please login again.';
      case 403:
        return 'Forbidden. You do not have permission.';
      case 404:
        return 'Resource not found.';
      case 409:
        return 'Conflict. The resource already exists.';
      case 422:
        return 'Validation error. Please check your input.';
      case 429:
        return 'Too many requests. Please try again later.';
      case 500:
        return 'Internal server error. Please try again later.';
      case 502:
        return 'Bad gateway. Please try again later.';
      case 503:
        return 'Service unavailable. Please try again later.';
      case 504:
        return 'Gateway timeout. Please try again later.';
      default:
        if (statusCode >= 400 && statusCode < 500) {
          return 'Client error occurred.';
        } else if (statusCode >= 500) {
          return 'Server error occurred. Please try again later.';
        }
        return 'An unexpected error occurred';
    }
  }
}
