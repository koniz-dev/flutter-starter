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
  });
}
