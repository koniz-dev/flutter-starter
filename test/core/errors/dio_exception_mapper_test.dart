import 'package:dio/dio.dart';
import 'package:flutter_starter/core/errors/dio_exception_mapper.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DioExceptionMapper', () {
    late RequestOptions requestOptions;

    setUp(() {
      requestOptions = RequestOptions(path: '/test');
    });

    group('Connection Timeout', () {
      test('should map connectionTimeout to NetworkException', () {
        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionTimeout,
          message: 'Connection timeout occurred',
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result, isA<NetworkException>());
        expect(result.message, contains('Connection timeout'));
        expect(result.code, 'CONNECTION_TIMEOUT');
      });
    });

    group('Send Timeout', () {
      test('should map sendTimeout to NetworkException', () {
        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.sendTimeout,
          message: 'Send timeout occurred',
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result, isA<NetworkException>());
        expect(result.message, contains('Send timeout'));
        expect(result.code, 'SEND_TIMEOUT');
      });
    });

    group('Receive Timeout', () {
      test('should map receiveTimeout to NetworkException', () {
        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.receiveTimeout,
          message: 'Receive timeout occurred',
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result, isA<NetworkException>());
        expect(result.message, contains('Receive timeout'));
        expect(result.code, 'RECEIVE_TIMEOUT');
      });
    });

    group('Transform Timeout', () {
      test('should map transformTimeout to NetworkException', () {
        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.transformTimeout,
          message: 'Transform timeout occurred',
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result, isA<NetworkException>());
        expect(result.message, contains('Transform timeout'));
        expect(result.code, 'TRANSFORM_TIMEOUT');
      });

      test('should handle null message in transformTimeout', () {
        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.transformTimeout,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result.code, 'TRANSFORM_TIMEOUT');
        expect(result.message, contains('Response processing timed out'));
      });
    });

    group('Bad Response', () {
      test('should map badResponse to ServerException with status code', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 404,
          data: {'message': 'Resource not found'},
        );

        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result, isA<ServerException>());
        final serverException = result as ServerException;
        expect(serverException.statusCode, 404);
        expect(serverException.message, 'Resource not found');
      });

      test('should extract error message from nested error object', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: {
            'error': {'message': 'Validation failed'},
          },
        );

        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result, isA<ServerException>());
        expect(result.message, 'Validation failed');
      });

      test('should use default message when response data is null', () {
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 500,
        );

        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result, isA<ServerException>());
        expect(result.message, contains('Internal server error'));
      });

      test('should extract error code from response data', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: {'message': 'Bad request', 'code': 'INVALID_INPUT'},
        );

        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result, isA<ServerException>());
        expect(result.code, 'INVALID_INPUT');
      });

      test('should handle string response data', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: 'Error message as string',
        );

        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result, isA<ServerException>());
        expect(result.message, 'Error message as string');
      });
    });

    group('Cancel', () {
      test('should map cancel to NetworkException', () {
        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.cancel,
          message: 'Request cancelled',
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result, isA<NetworkException>());
        expect(result.message, contains('Request cancelled'));
        expect(result.code, 'REQUEST_CANCELLED');
      });
    });

    group('Connection Error', () {
      test('should map connectionError to NetworkException', () {
        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionError,
          message: 'Connection error occurred',
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result, isA<NetworkException>());
        expect(result.message, contains('Connection error'));
        expect(result.code, 'CONNECTION_ERROR');
      });
    });

    group('Bad Certificate', () {
      test('should map badCertificate to NetworkException', () {
        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badCertificate,
          message: 'Bad certificate',
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result, isA<NetworkException>());
        expect(result.message, contains('Bad certificate'));
        expect(result.code, 'BAD_CERTIFICATE');
      });
    });

    group('Unknown carrying a domain exception', () {
      test('returns the AppException an interceptor put in error', () {
        final exception = DioException(
          requestOptions: RequestOptions(path: '/x'),
          error: const NetworkException('x', code: 'C'),
        );

        final result = DioExceptionMapper.map(exception);

        expect(result, isA<NetworkException>());
        expect(result.code, 'C');
        expect(result.message, 'x');
      });

      test('a non-domain error is still mapped as before', () {
        final exception = DioException(
          requestOptions: RequestOptions(path: '/x'),
          error: StateError('boom'),
        );

        expect(DioExceptionMapper.map(exception).code, 'UNKNOWN_NETWORK_ERROR');
      });
    });

    group('Unknown', () {
      test('should map unknown with SocketException to NetworkException', () {
        final dioException = DioException(
          requestOptions: requestOptions,
          message: 'SocketException: Connection refused',
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result, isA<NetworkException>());
        expect(result.message, contains('Network error'));
        expect(result.code, 'NETWORK_ERROR');
      });

      test('should map unknown to NetworkException', () {
        final dioException = DioException(
          requestOptions: requestOptions,
          message: 'Unknown error occurred',
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result, isA<NetworkException>());
        expect(result.message, contains('Network error'));
        expect(result.code, 'UNKNOWN_NETWORK_ERROR');
      });

      test('should handle null message in unknown error', () {
        final dioException = DioException(requestOptions: requestOptions);

        final result = DioExceptionMapper.map(dioException);

        expect(result, isA<NetworkException>());
        expect(result.message, contains('Network error'));
      });
    });

    group('Status Code Messages', () {
      test('should return appropriate message for 400', () {
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 400,
        );

        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result.message, contains('Bad request'));
      });

      test('should return appropriate message for 401', () {
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 401,
        );

        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result.message, contains('Unauthorized'));
      });

      test('should return appropriate message for 403', () {
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 403,
        );

        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result.message, contains('Forbidden'));
      });

      test('should return appropriate message for 404', () {
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 404,
        );

        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result.message, contains('Resource not found'));
      });

      test('should return appropriate message for 409', () {
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 409,
        );

        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result.message, contains('Conflict'));
      });

      test('should return appropriate message for 422', () {
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 422,
        );

        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result.message, contains('Validation error'));
      });

      test('should return appropriate message for 429', () {
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 429,
        );

        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result.message, contains('Too many requests'));
      });

      test('should return appropriate message for 500', () {
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 500,
        );

        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result.message, contains('Internal server error'));
      });

      test('should return appropriate message for 502', () {
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 502,
        );

        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result.message, contains('Bad gateway'));
      });

      test('should return appropriate message for 503', () {
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 503,
        );

        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result.message, contains('Service unavailable'));
      });

      test('should return appropriate message for 504', () {
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 504,
        );

        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result.message, contains('Gateway timeout'));
      });

      test('should return client error message for 4xx status codes', () {
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 418,
        );

        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result.message, contains('Client error occurred'));
      });

      test('should return server error message for 5xx status codes', () {
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 501,
        );

        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result.message, contains('Server error occurred'));
      });

      test('should return default message for null status code', () {
        final response = Response<dynamic>(requestOptions: requestOptions);

        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result.message, 'An unexpected error occurred');
      });

      test('should return default message when response is null', () {
        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result.message, 'An unexpected error occurred');
      });
    });

    group('Error Message Extraction Edge Cases', () {
      test('should extract message from error_message field', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: {'error_message': 'Custom error message'},
        );

        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result.message, 'Custom error message');
      });

      test('should extract message from msg field', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: {'msg': 'Message from msg field'},
        );

        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result.message, 'Message from msg field');
      });

      test('should extract message from error as string', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: {'error': 'Error as string'},
        );

        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result.message, 'Error as string');
      });

      test('should extract error code from error_code field', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: {'error_code': 'CUSTOM_ERROR_CODE'},
        );

        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result.code, 'CUSTOM_ERROR_CODE');
      });

      test('should extract error code from errorCode field', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: {'errorCode': 'CAMEL_CASE_ERROR'},
        );

        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result.code, 'CAMEL_CASE_ERROR');
      });

      test('should handle empty string response data', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: '',
        );

        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result.message, contains('Bad request'));
      });

      test('should handle unknown error with Network is unreachable', () {
        final dioException = DioException(
          requestOptions: requestOptions,
          message: 'Network is unreachable',
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result, isA<NetworkException>());
        expect(result.message, contains('Network error'));
        expect(result.code, 'NETWORK_ERROR');
      });

      test('should handle nested error with error field as string', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: {'error': 'Error as string in error field'},
        );

        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result.message, 'Error as string in error field');
      });

      test('should handle nested error with error.error field', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: {
            'error': {'error': 'Nested error.error field'},
          },
        );

        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result.message, 'Nested error.error field');
      });

      test('should handle empty nested error object', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 400,
          data: {'error': <String, dynamic>{}},
        );

        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result.message, contains('Bad request'));
      });

      test('should handle null message in connectionTimeout', () {
        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionTimeout,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result, isA<NetworkException>());
        expect(result.message, contains('Request timed out'));
      });

      test('should handle null message in sendTimeout', () {
        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.sendTimeout,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result, isA<NetworkException>());
        expect(result.message, contains('Request send timed out'));
      });

      test('should handle null message in receiveTimeout', () {
        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.receiveTimeout,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result, isA<NetworkException>());
        expect(result.message, contains('Response receive timed out'));
      });

      test('should handle null message in cancel', () {
        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.cancel,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result, isA<NetworkException>());
        expect(result.message, contains('Request was cancelled'));
      });

      test('should handle null message in connectionError', () {
        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionError,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result, isA<NetworkException>());
        expect(result.message, contains('Unable to connect to server'));
      });

      test('should handle null message in badCertificate', () {
        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badCertificate,
        );

        final result = DioExceptionMapper.map(dioException);

        expect(result, isA<NetworkException>());
        expect(result.message, contains('SSL certificate error'));
      });
    });

    // Body fields used to be cast with `as String?`,
    // so a list `message` or a numeric `code` threw a TypeError inside
    // ErrorInterceptor and the 400 reached the caller as a network error.
    group('bodies with non-String fields', () {
      DioException badResponse(int status, Object? body) => DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.badResponse,
        response: Response<Object?>(
          requestOptions: requestOptions,
          statusCode: status,
          data: body,
        ),
      );

      test('criterion 1: a NestJS-style list message maps to a 400 with the '
          'items joined', () {
        final result = DioExceptionMapper.map(
          badResponse(400, <String, dynamic>{
            'statusCode': 400,
            'message': ['email must be an email', 'password is too short'],
            'error': 'Bad Request',
          }),
        );

        expect(
          result,
          isA<ServerException>().having((e) => e.statusCode, 'statusCode', 400),
        );
        expect(
          result.message,
          'email must be an email; password is too short',
        );
      });

      test('criterion 2: an int or num code is kept as text', () {
        expect(
          DioExceptionMapper.map(
            badResponse(400, <String, dynamic>{
              'code': 1001,
              'message': 'Invalid',
            }),
          ).code,
          '1001',
        );
        expect(
          DioExceptionMapper.map(
            badResponse(400, <String, dynamic>{'error_code': 42.5}),
          ).code,
          '42.5',
        );
      });

      test('criterion 3: non-String values in any message or code field never '
          'throw', () {
        final odd = <Object?>[
          7,
          true,
          ['a', 3],
          <String, dynamic>{'nested': 1},
          null,
        ];
        for (final value in odd) {
          for (final field in [
            'message',
            'error',
            'error_message',
            'msg',
            'code',
            'error_code',
            'errorCode',
          ]) {
            final body = <String, dynamic>{field: value};
            expect(
              () => DioExceptionMapper.map(badResponse(422, body)),
              returnsNormally,
              reason: '$field: $value',
            );
            expect(
              DioExceptionMapper.map(badResponse(422, body)),
              isA<ServerException>(),
              reason: '$field: $value',
            );
          }
        }
      });

      test(
        'criterion 4: a nested error.code is read alongside error.message',
        () {
          final result = DioExceptionMapper.map(
            badResponse(409, <String, dynamic>{
              'error': {'message': 'x', 'code': 'E1'},
            }),
          );

          expect(result.message, 'x');
          expect(result.code, 'E1');
        },
      );

      test('an empty list message falls back to the status message', () {
        final result = DioExceptionMapper.map(
          badResponse(400, <String, dynamic>{'message': <String>[]}),
        );

        expect(result.message, 'Bad request. Please check your input.');
      });
    });
  });
}
