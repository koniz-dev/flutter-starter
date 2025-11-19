import 'package:dio/dio.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/network/interceptors/error_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test handler that captures rejected exceptions
class TestErrorInterceptorHandler extends ErrorInterceptorHandler {
  TestErrorInterceptorHandler() : super();

  DioException? rejectedException;

  @override
  void reject(DioException error, [bool callFollowingErrorInterceptor = true]) {
    rejectedException = error;
    // Don't call super.reject() to avoid async completion issues in tests
  }

  @override
  void resolve(
    Response<dynamic> response, [
    bool callFollowingResponseInterceptor = true,
  ]) {
    // Not used in error interceptor tests
  }
}

void main() {
  group('ErrorInterceptor', () {
    late ErrorInterceptor interceptor;
    late DioException dioException;
    late RequestOptions requestOptions;

    setUp(() {
      interceptor = ErrorInterceptor();
      requestOptions = RequestOptions(path: '/test');
    });

    test('should convert DioException to domain exception', () {
      // Arrange
      dioException = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.connectionTimeout,
        message: 'Connection timeout',
      );
      final handler = TestErrorInterceptorHandler();

      // Act
      interceptor.onError(dioException, handler);

      // Assert
      expect(handler.rejectedException, isNotNull);
      expect(handler.rejectedException?.error, isA<NetworkException>());
      final exception = handler.rejectedException?.error as NetworkException?;
      expect(exception?.message, contains('Connection timeout'));
    });

    test('should convert badResponse to ServerException', () {
      // Arrange
      final response = Response(
        requestOptions: requestOptions,
        statusCode: 404,
        data: {'message': 'Not found'},
      );
      dioException = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.badResponse,
        response: response,
      );
      final handler = TestErrorInterceptorHandler();

      // Act
      interceptor.onError(dioException, handler);

      // Assert
      expect(handler.rejectedException, isNotNull);
      expect(handler.rejectedException?.error, isA<ServerException>());
      final exception = handler.rejectedException?.error as ServerException?;
      expect(exception?.statusCode, 404);
    });

    test('should preserve error information in converted exception', () {
      // Arrange
      dioException = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.connectionError,
        message: 'Network error',
      );
      final handler = TestErrorInterceptorHandler();

      // Act
      interceptor.onError(dioException, handler);

      // Assert
      expect(handler.rejectedException, isNotNull);
      expect(handler.rejectedException?.error, isA<AppException>());
      final exception = handler.rejectedException?.error as AppException?;
      expect(exception?.message, contains('Network error'));
    });

    test('should handle all DioException types', () {
      final types = [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.badResponse,
        DioExceptionType.cancel,
        DioExceptionType.connectionError,
        DioExceptionType.badCertificate,
        DioExceptionType.unknown,
      ];

      for (final type in types) {
        // Arrange
        dioException = DioException(
          requestOptions: requestOptions,
          type: type,
        );
        final handler = TestErrorInterceptorHandler();

        // Act
        interceptor.onError(dioException, handler);

        // Assert
        expect(
          handler.rejectedException,
          isNotNull,
          reason: 'Type $type should be handled',
        );
        expect(handler.rejectedException?.error, isA<AppException>());
      }
    });

    group('Edge Cases', () {
      test('should preserve request options in rejected exception', () {
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionTimeout,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        expect(handler.rejectedException?.requestOptions, requestOptions);
      });

      test('should preserve response in rejected exception', () {
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 500,
        );
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        expect(handler.rejectedException?.response, response);
      });

      test('should preserve exception type in rejected exception', () {
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.sendTimeout,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        expect(handler.rejectedException?.type, DioExceptionType.sendTimeout);
      });

      test('should set message from domain exception', () {
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionError,
          message: 'Connection error',
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        expect(handler.rejectedException?.message, isNotEmpty);
        final exception = handler.rejectedException?.error as AppException?;
        expect(handler.rejectedException?.message, exception?.message);
      });

      test('should handle null response', () {
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionTimeout,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        expect(handler.rejectedException, isNotNull);
        expect(handler.rejectedException?.response, isNull);
      });
    });

    group('Status Code Handling', () {
      test('should handle 400 Bad Request', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: {'message': 'Bad request'},
        );
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        expect(handler.rejectedException?.error, isA<ServerException>());
        final exception = handler.rejectedException?.error as ServerException?;
        expect(exception?.statusCode, 400);
        expect(exception?.message, contains('Bad request'));
      });

      test('should handle 401 Unauthorized', () {
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 401,
        );
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        expect(handler.rejectedException?.error, isA<ServerException>());
        final exception = handler.rejectedException?.error as ServerException?;
        expect(exception?.statusCode, 401);
        expect(exception?.message, contains('Unauthorized'));
      });

      test('should handle 403 Forbidden', () {
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 403,
        );
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        expect(handler.rejectedException?.error, isA<ServerException>());
        final exception = handler.rejectedException?.error as ServerException?;
        expect(exception?.statusCode, 403);
        expect(exception?.message, contains('Forbidden'));
      });

      test('should handle 409 Conflict', () {
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 409,
        );
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        expect(handler.rejectedException?.error, isA<ServerException>());
        final exception = handler.rejectedException?.error as ServerException?;
        expect(exception?.statusCode, 409);
        expect(exception?.message, contains('Conflict'));
      });

      test('should handle 422 Validation Error', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 422,
          data: {'message': 'Validation failed'},
        );
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        expect(handler.rejectedException?.error, isA<ServerException>());
        final exception = handler.rejectedException?.error as ServerException?;
        expect(exception?.statusCode, 422);
        expect(exception?.message, 'Validation failed');
      });

      test('should handle 429 Too Many Requests', () {
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 429,
        );
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        expect(handler.rejectedException?.error, isA<ServerException>());
        final exception = handler.rejectedException?.error as ServerException?;
        expect(exception?.statusCode, 429);
        expect(exception?.message, contains('Too many requests'));
      });

      test('should handle 500 Internal Server Error', () {
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 500,
        );
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        expect(handler.rejectedException?.error, isA<ServerException>());
        final exception = handler.rejectedException?.error as ServerException?;
        expect(exception?.statusCode, 500);
        expect(exception?.message, contains('Internal server error'));
      });

      test('should handle 502 Bad Gateway', () {
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 502,
        );
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        expect(handler.rejectedException?.error, isA<ServerException>());
        final exception = handler.rejectedException?.error as ServerException?;
        expect(exception?.statusCode, 502);
        expect(exception?.message, contains('Bad gateway'));
      });

      test('should handle 503 Service Unavailable', () {
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 503,
        );
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        expect(handler.rejectedException?.error, isA<ServerException>());
        final exception = handler.rejectedException?.error as ServerException?;
        expect(exception?.statusCode, 503);
        expect(exception?.message, contains('Service unavailable'));
      });

      test('should handle 504 Gateway Timeout', () {
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 504,
        );
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        expect(handler.rejectedException?.error, isA<ServerException>());
        final exception = handler.rejectedException?.error as ServerException?;
        expect(exception?.statusCode, 504);
        expect(exception?.message, contains('Gateway timeout'));
      });

      test('should handle unknown status codes', () {
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 418, // I'm a teapot
        );
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        expect(handler.rejectedException?.error, isA<ServerException>());
        final exception = handler.rejectedException?.error as ServerException?;
        expect(exception?.statusCode, 418);
      });
    });

    group('Error Message Extraction', () {
      test('should extract message from nested error object', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: {
            'error': {
              'message': 'Nested error message',
            },
          },
        );
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        final exception = handler.rejectedException?.error as ServerException?;
        expect(exception?.message, 'Nested error message');
      });

      test('should extract message from error.error field', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: {
            'error': {
              'error': 'Alternative error message',
            },
          },
        );
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        final exception = handler.rejectedException?.error as ServerException?;
        expect(exception?.message, 'Alternative error message');
      });

      test('should extract message from error_message field', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: {
            'error_message': 'Error message from error_message field',
          },
        );
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        final exception = handler.rejectedException?.error as ServerException?;
        expect(exception?.message, 'Error message from error_message field');
      });

      test('should extract message from msg field', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: {
            'msg': 'Message from msg field',
          },
        );
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        final exception = handler.rejectedException?.error as ServerException?;
        expect(exception?.message, 'Message from msg field');
      });

      test('should extract message from string error field', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: {
            'error': 'String error message',
          },
        );
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        final exception = handler.rejectedException?.error as ServerException?;
        expect(exception?.message, 'String error message');
      });

      test('should extract message from string response data', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: 'String response data',
        );
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        final exception = handler.rejectedException?.error as ServerException?;
        expect(exception?.message, 'String response data');
      });

      test('should use default message when no message found', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: {'other_field': 'value'},
        );
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        final exception = handler.rejectedException?.error as ServerException?;
        expect(exception?.message, contains('Bad request'));
      });
    });

    group('Error Code Extraction', () {
      test('should extract error code from code field', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: {
            'code': 'INVALID_INPUT',
            'message': 'Invalid input',
          },
        );
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        final exception = handler.rejectedException?.error as ServerException?;
        expect(exception?.code, 'INVALID_INPUT');
      });

      test('should extract error code from error_code field', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: {
            'error_code': 'VALIDATION_ERROR',
            'message': 'Validation error',
          },
        );
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        final exception = handler.rejectedException?.error as ServerException?;
        expect(exception?.code, 'VALIDATION_ERROR');
      });

      test('should extract error code from errorCode field', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: {
            'errorCode': 'AUTH_FAILED',
            'message': 'Authentication failed',
          },
        );
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        final exception = handler.rejectedException?.error as ServerException?;
        expect(exception?.code, 'AUTH_FAILED');
      });

      test('should return null when no error code found', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: {
            'message': 'Error without code',
          },
        );
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        final exception = handler.rejectedException?.error as ServerException?;
        expect(exception?.code, isNull);
      });
    });

    group('Network Exception Types', () {
      test('should handle sendTimeout', () {
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.sendTimeout,
          message: 'Send timeout',
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        expect(handler.rejectedException?.error, isA<NetworkException>());
        final exception = handler.rejectedException?.error as NetworkException?;
        expect(exception?.code, 'SEND_TIMEOUT');
        expect(exception?.message, contains('Send timeout'));
      });

      test('should handle receiveTimeout', () {
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.receiveTimeout,
          message: 'Receive timeout',
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        expect(handler.rejectedException?.error, isA<NetworkException>());
        final exception = handler.rejectedException?.error as NetworkException?;
        expect(exception?.code, 'RECEIVE_TIMEOUT');
        expect(exception?.message, contains('Receive timeout'));
      });

      test('should handle cancel', () {
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.cancel,
          message: 'Request cancelled',
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        expect(handler.rejectedException?.error, isA<NetworkException>());
        final exception = handler.rejectedException?.error as NetworkException?;
        expect(exception?.code, 'REQUEST_CANCELLED');
        expect(exception?.message, contains('Request cancelled'));
      });

      test('should handle badCertificate', () {
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badCertificate,
          message: 'Bad certificate',
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        expect(handler.rejectedException?.error, isA<NetworkException>());
        final exception = handler.rejectedException?.error as NetworkException?;
        expect(exception?.code, 'BAD_CERTIFICATE');
        expect(exception?.message, contains('Bad certificate'));
      });

      test('should handle unknown with SocketException message', () {
        dioException = DioException(
          requestOptions: requestOptions,
          message: 'SocketException: Failed host lookup',
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        expect(handler.rejectedException?.error, isA<NetworkException>());
        final exception = handler.rejectedException?.error as NetworkException?;
        expect(exception?.code, 'NETWORK_ERROR');
        expect(exception?.message, contains('Network error'));
      });

      test('should handle unknown with Network is unreachable message', () {
        dioException = DioException(
          requestOptions: requestOptions,
          message: 'Network is unreachable',
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        expect(handler.rejectedException?.error, isA<NetworkException>());
        final exception = handler.rejectedException?.error as NetworkException?;
        expect(exception?.code, 'NETWORK_ERROR');
        expect(exception?.message, contains('Network error'));
      });

      test('should handle unknown with generic message', () {
        dioException = DioException(
          requestOptions: requestOptions,
          message: 'Unknown error',
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        expect(handler.rejectedException?.error, isA<NetworkException>());
        final exception = handler.rejectedException?.error as NetworkException?;
        expect(exception?.code, 'UNKNOWN_NETWORK_ERROR');
        expect(exception?.message, contains('Network error'));
      });

      test('should handle unknown with null message', () {
        dioException = DioException(
          requestOptions: requestOptions,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        expect(handler.rejectedException?.error, isA<NetworkException>());
        final exception = handler.rejectedException?.error as NetworkException?;
        expect(exception?.code, 'UNKNOWN_NETWORK_ERROR');
        expect(exception?.message, contains('unexpected network error'));
      });
    });

    group('Null and Empty Handling', () {
      test('should handle null message in DioException', () {
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionTimeout,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        expect(handler.rejectedException?.error, isA<NetworkException>());
        final exception = handler.rejectedException?.error as NetworkException?;
        expect(exception?.message, contains('Request timed out'));
      });

      test('should handle empty string message', () {
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionTimeout,
          message: '',
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        expect(handler.rejectedException?.error, isA<NetworkException>());
        final exception = handler.rejectedException?.error as NetworkException?;
        expect(exception?.message, contains('Connection timeout'));
      });

      test('should handle null response data', () {
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 400,
        );
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        expect(handler.rejectedException?.error, isA<ServerException>());
        final exception = handler.rejectedException?.error as ServerException?;
        expect(exception?.message, contains('Bad request'));
      });

      test('should handle empty response data', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: <String, dynamic>{},
        );
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        expect(handler.rejectedException?.error, isA<ServerException>());
        final exception = handler.rejectedException?.error as ServerException?;
        expect(exception?.message, contains('Bad request'));
      });

      test('should handle empty string response data', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: '',
        );
        dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);

        expect(handler.rejectedException?.error, isA<ServerException>());
        final exception = handler.rejectedException?.error as ServerException?;
        expect(exception?.message, contains('Bad request'));
      });
    });
  });
}
