import 'package:dio/dio.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';

/// Mapper for converting DioException to domain exceptions
class DioExceptionMapper {
  /// Converts a [DioException] to an appropriate domain exception
  ///
  /// Maps different DioException types to domain exceptions:
  /// - Connection/timeout errors → NetworkException
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
          final nestedMessage = error['message'] as String? ??
              error['error'] as String?;
          if (nestedMessage != null && nestedMessage.isNotEmpty) {
            return nestedMessage;
          }
        }

        // Try common error message fields
        final message = data['message'] as String? ??
            (error is String ? error : null) ??
            data['error_message'] as String? ??
            data['msg'] as String?;

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
      // Try common error code fields
      return data['code'] as String? ??
          data['error_code'] as String? ??
          data['errorCode'] as String?;
    }

    return null;
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
