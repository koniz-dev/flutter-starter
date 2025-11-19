import 'package:dio/dio.dart';
import 'package:flutter_starter/core/network/interceptors/performance_interceptor.dart';
import 'package:flutter_starter/core/performance/performance_attributes.dart';
import 'package:flutter_starter/core/performance/performance_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPerformanceService extends Mock implements PerformanceService {}

class MockPerformanceTrace extends Mock implements PerformanceTrace {}

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
  group('PerformanceInterceptor', () {
    late PerformanceInterceptor interceptor;
    late MockPerformanceService mockPerformanceService;
    late MockPerformanceTrace mockTrace;
    late RequestOptions requestOptions;

    setUp(() {
      mockPerformanceService = MockPerformanceService();
      mockTrace = MockPerformanceTrace();
      interceptor = PerformanceInterceptor(
        performanceService: mockPerformanceService,
      );
      requestOptions = RequestOptions(
        path: '/api/test',
        method: 'GET',
        baseUrl: 'https://api.example.com',
      );

      // Register fallback values
      registerFallbackValue('GET');
      registerFallbackValue('/api/test');
      registerFallbackValue(PerformanceAttributes.httpMethod);
      registerFallbackValue(PerformanceAttributes.httpPath);
      registerFallbackValue(PerformanceMetrics.success);
      registerFallbackValue(PerformanceMetrics.error);
    });

    group('onRequest', () {
      test('should start trace when performance service returns trace', () {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        when(() => mockPerformanceService.startHttpTrace(any(), any()))
            .thenReturn(mockTrace);
        when(() => mockTrace.putAttribute(any(), any())).thenReturn(null);
        when(() => mockTrace.startSync()).thenReturn(null);

        // Act
        interceptor.onRequest(requestOptions, handler);

        // Assert
        verify(() => mockPerformanceService.startHttpTrace('GET', '/api/test'))
            .called(1);
        verify(() => mockTrace.putAttribute(
              PerformanceAttributes.httpMethod,
              'GET',
            ),).called(1);
        verify(() => mockTrace.putAttribute(
              PerformanceAttributes.httpPath,
              '/api/test',
            ),).called(1);
        verify(() => mockTrace.startSync()).called(1);
        expect(requestOptions.extra['performance_trace'], mockTrace);
      });

      test('should not start trace when performance service returns null', () {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        when(() => mockPerformanceService.startHttpTrace(any(), any()))
            .thenReturn(null);

        // Act
        interceptor.onRequest(requestOptions, handler);

        // Assert
        verify(() => mockPerformanceService.startHttpTrace('GET', '/api/test'))
            .called(1);
        verifyNever(() => mockTrace.putAttribute(any(), any()));
        verifyNever(() => mockTrace.startSync());
        expect(requestOptions.extra['performance_trace'], isNull);
      });

      test('should store trace in request options extra', () {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        when(() => mockPerformanceService.startHttpTrace(any(), any()))
            .thenReturn(mockTrace);
        when(() => mockTrace.putAttribute(any(), any())).thenReturn(null);
        when(() => mockTrace.startSync()).thenReturn(null);

        // Act
        interceptor.onRequest(requestOptions, handler);

        // Assert
        expect(requestOptions.extra['performance_trace'], mockTrace);
      });

      test('should handle different HTTP methods', () {
        // Arrange
        final methods = ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'];
        for (final method in methods) {
          final options = RequestOptions(
            path: '/api/test',
            method: method,
          );
          final handler = TestRequestInterceptorHandler();
          when(() => mockPerformanceService.startHttpTrace(any(), any()))
              .thenReturn(mockTrace);
          when(() => mockTrace.putAttribute(any(), any())).thenReturn(null);
          when(() => mockTrace.startSync()).thenReturn(null);

          // Act
          interceptor.onRequest(options, handler);

          // Assert
          verify(() => mockPerformanceService.startHttpTrace(method, '/api/test'))
              .called(1);
          verify(() => mockTrace.putAttribute(
                PerformanceAttributes.httpMethod,
                method,
              ),).called(1);
          clearInteractions(mockPerformanceService);
          clearInteractions(mockTrace);
        }
      });
    });

    group('onResponse', () {
      test('should record success metric for 2xx status codes', () {
        // Arrange
        requestOptions.extra['performance_trace'] = mockTrace;
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 200,
          data: {'key': 'value'},
        );
        final handler = TestResponseInterceptorHandler();
        when(() => mockTrace.putAttribute(any(), any())).thenReturn(null);
        when(() => mockTrace.putMetric(any(), any())).thenReturn(null);
        when(() => mockTrace.stopSync()).thenReturn(null);

        // Act
        interceptor.onResponse(response, handler);

        // Assert
        verify(() => mockTrace.putAttribute(
              PerformanceAttributes.httpStatusCode,
              '200',
            ),).called(1);
        verify(() => mockTrace.putMetric(PerformanceMetrics.success, 1))
            .called(1);
        verify(() => mockTrace.stopSync()).called(1);
      });

      test('should record error metric for non-2xx status codes', () {
        // Arrange
        requestOptions.extra['performance_trace'] = mockTrace;
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 404,
        );
        final handler = TestResponseInterceptorHandler();
        when(() => mockTrace.putAttribute(any(), any())).thenReturn(null);
        when(() => mockTrace.putMetric(any(), any())).thenReturn(null);
        when(() => mockTrace.stopSync()).thenReturn(null);

        // Act
        interceptor.onResponse(response, handler);

        // Assert
        verify(() => mockTrace.putAttribute(
              PerformanceAttributes.httpStatusCode,
              '404',
            ),).called(1);
        verify(() => mockTrace.putMetric(PerformanceMetrics.error, 1))
            .called(1);
        verify(() => mockTrace.stopSync()).called(1);
      });

      test('should record response size when data is available', () {
        // Arrange
        requestOptions.extra['performance_trace'] = mockTrace;
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 200,
          data: {'key': 'value'},
        );
        final handler = TestResponseInterceptorHandler();
        when(() => mockTrace.putAttribute(any(), any())).thenReturn(null);
        when(() => mockTrace.putMetric(any(), any())).thenReturn(null);
        when(() => mockTrace.stopSync()).thenReturn(null);

        // Act
        interceptor.onResponse(response, handler);

        // Assert
        verify(() => mockTrace.putAttribute(
              PerformanceAttributes.httpResponseSize,
              any(),
            ),).called(1);
      });

      test('should handle response with null status code', () {
        // Arrange
        requestOptions.extra['performance_trace'] = mockTrace;
        final response = Response<dynamic>(
          requestOptions: requestOptions,
        );
        final handler = TestResponseInterceptorHandler();
        when(() => mockTrace.putAttribute(any(), any())).thenReturn(null);
        when(() => mockTrace.putMetric(any(), any())).thenReturn(null);
        when(() => mockTrace.stopSync()).thenReturn(null);

        // Act
        interceptor.onResponse(response, handler);

        // Assert
        verify(() => mockTrace.putAttribute(
              PerformanceAttributes.httpStatusCode,
              '0',
            ),).called(1);
        verify(() => mockTrace.putMetric(PerformanceMetrics.error, 1))
            .called(1);
      });

      test('should handle response with string data', () {
        // Arrange
        requestOptions.extra['performance_trace'] = mockTrace;
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 200,
          data: 'test string',
        );
        final handler = TestResponseInterceptorHandler();
        when(() => mockTrace.putAttribute(any(), any())).thenReturn(null);
        when(() => mockTrace.putMetric(any(), any())).thenReturn(null);
        when(() => mockTrace.stopSync()).thenReturn(null);

        // Act
        interceptor.onResponse(response, handler);

        // Assert
        verify(() => mockTrace.putAttribute(
              PerformanceAttributes.httpResponseSize,
              any(),
            ),).called(1);
      });

      test('should handle response with list data', () {
        // Arrange
        requestOptions.extra['performance_trace'] = mockTrace;
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 200,
          data: [1, 2, 3, 4, 5],
        );
        final handler = TestResponseInterceptorHandler();
        when(() => mockTrace.putAttribute(any(), any())).thenReturn(null);
        when(() => mockTrace.putMetric(any(), any())).thenReturn(null);
        when(() => mockTrace.stopSync()).thenReturn(null);

        // Act
        interceptor.onResponse(response, handler);

        // Assert
        verify(() => mockTrace.putAttribute(
              PerformanceAttributes.httpResponseSize,
              any(),
            ),).called(1);
      });

      test('should handle response with map data', () {
        // Arrange
        requestOptions.extra['performance_trace'] = mockTrace;
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 200,
          data: {'key1': 'value1', 'key2': 'value2'},
        );
        final handler = TestResponseInterceptorHandler();
        when(() => mockTrace.putAttribute(any(), any())).thenReturn(null);
        when(() => mockTrace.putMetric(any(), any())).thenReturn(null);
        when(() => mockTrace.stopSync()).thenReturn(null);

        // Act
        interceptor.onResponse(response, handler);

        // Assert
        verify(() => mockTrace.putAttribute(
              PerformanceAttributes.httpResponseSize,
              any(),
            ),).called(1);
      });

      test('should handle response with null data', () {
        // Arrange
        requestOptions.extra['performance_trace'] = mockTrace;
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 204,
        );
        final handler = TestResponseInterceptorHandler();
        when(() => mockTrace.putAttribute(any(), any())).thenReturn(null);
        when(() => mockTrace.putMetric(any(), any())).thenReturn(null);
        when(() => mockTrace.stopSync()).thenReturn(null);

        // Act
        interceptor.onResponse(response, handler);

        // Assert
        verifyNever(() => mockTrace.putAttribute(
              PerformanceAttributes.httpResponseSize,
              any(),
            ),);
        verify(() => mockTrace.stopSync()).called(1);
      });

      test('should handle exception when estimating response size', () {
        // Arrange
        requestOptions.extra['performance_trace'] = mockTrace;
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 200,
          data: Object(), // Object that might cause exception
        );
        final handler = TestResponseInterceptorHandler();
        when(() => mockTrace.putAttribute(any(), any())).thenReturn(null);
        when(() => mockTrace.putMetric(any(), any())).thenReturn(null);
        when(() => mockTrace.stopSync()).thenReturn(null);

        // Act
        interceptor.onResponse(response, handler);

        // Assert
        // Should not throw, exception is caught
        verify(() => mockTrace.stopSync()).called(1);
      });

      test('should not process trace when trace is null', () {
        // Arrange
        requestOptions.extra.remove('performance_trace');
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 200,
        );
        final handler = TestResponseInterceptorHandler();

        // Act
        interceptor.onResponse(response, handler);

        // Assert
        verifyNever(() => mockTrace.putAttribute(any(), any()));
        verifyNever(() => mockTrace.putMetric(any(), any()));
        verifyNever(() => mockTrace.stopSync());
      });
    });

    group('onError', () {
      test('should record error metric and error type', () {
        // Arrange
        requestOptions.extra['performance_trace'] = mockTrace;
        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionTimeout,
          message: 'Connection timeout',
        );
        final handler = TestErrorInterceptorHandler();
        when(() => mockTrace.putMetric(any(), any())).thenReturn(null);
        when(() => mockTrace.putAttribute(any(), any())).thenReturn(null);
        when(() => mockTrace.stopSync()).thenReturn(null);

        // Act
        interceptor.onError(dioException, handler);

        // Assert
        verify(() => mockTrace.putMetric(PerformanceMetrics.error, 1))
            .called(1);
        verify(() => mockTrace.putAttribute(
              PerformanceAttributes.errorType,
              any(that: contains('connectionTimeout')),
            ),).called(1);
        verify(() => mockTrace.stopSync()).called(1);
      });

      test('should include status code when response is available', () {
        // Arrange
        requestOptions.extra['performance_trace'] = mockTrace;
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 500,
        );
        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );
        final handler = TestErrorInterceptorHandler();
        when(() => mockTrace.putMetric(any(), any())).thenReturn(null);
        when(() => mockTrace.putAttribute(any(), any())).thenReturn(null);
        when(() => mockTrace.stopSync()).thenReturn(null);

        // Act
        interceptor.onError(dioException, handler);

        // Assert
        verify(() => mockTrace.putAttribute(
              PerformanceAttributes.httpStatusCode,
              '500',
            ),).called(1);
      });

      test('should handle error without response', () {
        // Arrange
        requestOptions.extra['performance_trace'] = mockTrace;
        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionTimeout,
        );
        final handler = TestErrorInterceptorHandler();
        when(() => mockTrace.putMetric(any(), any())).thenReturn(null);
        when(() => mockTrace.putAttribute(any(), any())).thenReturn(null);
        when(() => mockTrace.stopSync()).thenReturn(null);

        // Act
        interceptor.onError(dioException, handler);

        // Assert
        verifyNever(() => mockTrace.putAttribute(
              PerformanceAttributes.httpStatusCode,
              any(),
            ),);
        verify(() => mockTrace.stopSync()).called(1);
      });

      test('should handle different error types', () {
        // Arrange
        final errorTypes = [
          DioExceptionType.connectionTimeout,
          DioExceptionType.sendTimeout,
          DioExceptionType.receiveTimeout,
          DioExceptionType.badResponse,
          DioExceptionType.cancel,
          DioExceptionType.connectionError,
          DioExceptionType.badCertificate,
          DioExceptionType.unknown,
        ];

        for (final errorType in errorTypes) {
          requestOptions.extra['performance_trace'] = mockTrace;
          final dioException = DioException(
            requestOptions: requestOptions,
            type: errorType,
          );
          final handler = TestErrorInterceptorHandler();
          when(() => mockTrace.putMetric(any(), any())).thenReturn(null);
          when(() => mockTrace.putAttribute(any(), any())).thenReturn(null);
          when(() => mockTrace.stopSync()).thenReturn(null);

          // Act
          interceptor.onError(dioException, handler);

          // Assert
          verify(() => mockTrace.putMetric(PerformanceMetrics.error, 1))
              .called(1);
          verify(() => mockTrace.stopSync()).called(1);
          clearInteractions(mockTrace);
        }
      });

      test('should not process trace when trace is null', () {
        // Arrange
        requestOptions.extra.remove('performance_trace');
        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionTimeout,
        );
        final handler = TestErrorInterceptorHandler();

        // Act
        interceptor.onError(dioException, handler);

        // Assert
        verifyNever(() => mockTrace.putMetric(any(), any()));
        verifyNever(() => mockTrace.putAttribute(any(), any()));
        verifyNever(() => mockTrace.stopSync());
      });
    });

    group('_getTrace', () {
      test('should return trace when present in extra', () {
        // Arrange
        requestOptions.extra['performance_trace'] = mockTrace;

        // Act
        interceptor.onRequest(requestOptions, TestRequestInterceptorHandler());

        // Assert
        expect(requestOptions.extra['performance_trace'], mockTrace);
      });

      test('should return null when trace is not PerformanceTrace', () {
        // Arrange
        requestOptions.extra['performance_trace'] = 'not a trace';

        // Act & Assert
        // This is tested indirectly through onResponse/onError
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 200,
        );
        final handler = TestResponseInterceptorHandler();

        interceptor.onResponse(response, handler);

        // Should not call trace methods since trace is not PerformanceTrace
        verifyNever(() => mockTrace.putAttribute(any(), any()));
      });
    });

    group('_estimateResponseSize', () {
      test('should estimate size for string data', () {
        // Arrange
        requestOptions.extra['performance_trace'] = mockTrace;
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 200,
          data: 'test',
        );
        final handler = TestResponseInterceptorHandler();
        when(() => mockTrace.putAttribute(any(), any())).thenReturn(null);
        when(() => mockTrace.putMetric(any(), any())).thenReturn(null);
        when(() => mockTrace.stopSync()).thenReturn(null);

        // Act
        interceptor.onResponse(response, handler);

        // Assert
        verify(() => mockTrace.putAttribute(
              PerformanceAttributes.httpResponseSize,
              '8', // 'test'.length * 2 = 4 * 2 = 8
            ),).called(1);
      });

      test('should estimate size for list data', () {
        // Arrange
        requestOptions.extra['performance_trace'] = mockTrace;
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 200,
          data: [1, 2, 3],
        );
        final handler = TestResponseInterceptorHandler();
        when(() => mockTrace.putAttribute(any(), any())).thenReturn(null);
        when(() => mockTrace.putMetric(any(), any())).thenReturn(null);
        when(() => mockTrace.stopSync()).thenReturn(null);

        // Act
        interceptor.onResponse(response, handler);

        // Assert
        verify(() => mockTrace.putAttribute(
              PerformanceAttributes.httpResponseSize,
              '300', // 3 * 100
            ),).called(1);
      });

      test('should estimate size for map data', () {
        // Arrange
        requestOptions.extra['performance_trace'] = mockTrace;
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 200,
          data: {'key1': 'value1', 'key2': 'value2'},
        );
        final handler = TestResponseInterceptorHandler();
        when(() => mockTrace.putAttribute(any(), any())).thenReturn(null);
        when(() => mockTrace.putMetric(any(), any())).thenReturn(null);
        when(() => mockTrace.stopSync()).thenReturn(null);

        // Act
        interceptor.onResponse(response, handler);

        // Assert
        verify(() => mockTrace.putAttribute(
              PerformanceAttributes.httpResponseSize,
              '400', // 2 * 200
            ),).called(1);
      });
    });
  });
}
