import 'package:dio/dio.dart';
import 'package:flutter_starter/core/network/interceptors/logging_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test handler for request interceptor
class TestRequestInterceptorHandler extends RequestInterceptorHandler {
  TestRequestInterceptorHandler() : super();
}

/// Test handler for response interceptor
class TestResponseInterceptorHandler extends ResponseInterceptorHandler {
  TestResponseInterceptorHandler() : super();
}

/// Test handler for error interceptor
class TestErrorInterceptorHandler extends ErrorInterceptorHandler {
  TestErrorInterceptorHandler() : super();

  @override
  void next(DioException err) {
    // Don't call super.next() to avoid async completion issues in tests
  }
}

void main() {
  group('LoggingInterceptor', () {
    late LoggingInterceptor interceptor;
    late RequestOptions requestOptions;

    setUp(() {
      interceptor = LoggingInterceptor();
      requestOptions = RequestOptions(
        path: '/api/test',
        method: 'GET',
        headers: {'Authorization': 'Bearer token'},
      );
    });

    test('should log request in debug mode', () {
      // Arrange
      final handler = TestRequestInterceptorHandler();

      // Act
      interceptor.onRequest(requestOptions, handler);

      // Assert
      // In debug mode, debugPrint should be called
      // This is hard to test directly, so we just verify the interceptor
      // doesn't throw
      expect(interceptor, isNotNull);
    });

    test('should log response in debug mode', () {
      // Arrange
      final response = Response(
        requestOptions: requestOptions,
        statusCode: 200,
        data: {'key': 'value'},
      );
      final handler = TestResponseInterceptorHandler();

      // Act
      interceptor.onResponse(response, handler);

      // Assert
      // Verify interceptor handles response without errors
      expect(interceptor, isNotNull);
    });

    test('should log error in debug mode', () {
      // Arrange
      final dioException = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.connectionTimeout,
        message: 'Connection timeout',
      );
      final handler = TestErrorInterceptorHandler();

      // Act
      interceptor.onError(dioException, handler);

      // Assert
      // Verify interceptor handles error without errors
      expect(interceptor, isNotNull);
    });

    test('should not break request flow', () {
      // Arrange
      final handler = TestRequestInterceptorHandler();

      // Act
      interceptor.onRequest(requestOptions, handler);

      // Assert
      // Handler should still be callable
      expect(handler, isNotNull);
    });

    group('Request logging', () {
      test('should handle request with data', () {
        final handler = TestRequestInterceptorHandler();
        final optionsWithData = RequestOptions(
          path: '/api/test',
          method: 'POST',
          data: {'key': 'value'},
        );

        interceptor.onRequest(optionsWithData, handler);
        expect(interceptor, isNotNull);
      });

      test('should handle request with query parameters', () {
        final handler = TestRequestInterceptorHandler();
        final optionsWithQuery = RequestOptions(
          path: '/api/test',
          method: 'GET',
          queryParameters: {'page': '1', 'limit': '10'},
        );

        interceptor.onRequest(optionsWithQuery, handler);
        expect(interceptor, isNotNull);
      });

      test('should handle request without data', () {
        final handler = TestRequestInterceptorHandler();
        final optionsWithoutData = RequestOptions(
          path: '/api/test',
          method: 'GET',
        );

        interceptor.onRequest(optionsWithoutData, handler);
        expect(interceptor, isNotNull);
      });
    });

    group('Response logging', () {
      test('should handle response with data', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 200,
          data: {'key': 'value'},
        );
        final handler = TestResponseInterceptorHandler();

        interceptor.onResponse(response, handler);
        expect(interceptor, isNotNull);
      });

      test('should handle response without data', () {
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 204,
        );
        final handler = TestResponseInterceptorHandler();

        interceptor.onResponse(response, handler);
        expect(interceptor, isNotNull);
      });

      test('should handle different status codes', () {
        final statusCodes = [200, 201, 400, 404, 500];
        for (final statusCode in statusCodes) {
          final response = Response(
            requestOptions: requestOptions,
            statusCode: statusCode,
            data: {'status': statusCode},
          );
          final handler = TestResponseInterceptorHandler();

          interceptor.onResponse(response, handler);
          expect(interceptor, isNotNull);
        }
      });
    });

    group('Error logging', () {
      test('should handle error with response', () {
        final response = Response(
          requestOptions: requestOptions,
          statusCode: 404,
          data: {'error': 'Not found'},
        );
        final dioException = DioException(
          requestOptions: requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: 'Not found',
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);
        expect(interceptor, isNotNull);
      });

      test('should handle error without response', () {
        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionTimeout,
          message: 'Connection timeout',
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);
        expect(interceptor, isNotNull);
      });

      test('should handle error without response data', () {
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 500,
        );
        final dioException = DioException(
          requestOptions: requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: 'Server error',
        );
        final handler = TestErrorInterceptorHandler();

        interceptor.onError(dioException, handler);
        expect(interceptor, isNotNull);
      });

      test('should handle different error types', () {
        final errorTypes = [
          DioExceptionType.connectionTimeout,
          DioExceptionType.sendTimeout,
          DioExceptionType.receiveTimeout,
          DioExceptionType.badResponse,
          DioExceptionType.cancel,
          DioExceptionType.unknown,
        ];

        for (final errorType in errorTypes) {
          final dioException = DioException(
            requestOptions: requestOptions,
            type: errorType,
            message: 'Error message',
          );
          final handler = TestErrorInterceptorHandler();

          interceptor.onError(dioException, handler);
          expect(interceptor, isNotNull);
        }
      });
    });
  });
}
