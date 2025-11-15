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
            'error': {
              'message': 'Validation failed',
            },
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
          data: {
            'message': 'Bad request',
            'code': 'INVALID_INPUT',
          },
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
        final dioException = DioException(
          requestOptions: requestOptions,
        );

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
    });
  });
}
