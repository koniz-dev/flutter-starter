import 'package:dio/dio.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/network/interceptors/api_logging_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingService extends Mock implements LoggingService {}

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
  group('ApiLoggingInterceptor', () {
    late ApiLoggingInterceptor interceptor;
    late MockLoggingService mockLoggingService;
    late RequestOptions requestOptions;

    setUp(() {
      mockLoggingService = MockLoggingService();
      interceptor = ApiLoggingInterceptor(
        loggingService: mockLoggingService,
      );
      requestOptions = RequestOptions(
        path: '/api/test',
        method: 'GET',
        baseUrl: 'https://api.example.com',
        headers: {'Authorization': 'Bearer token'},
      );

      // Register fallback values for mocktail
      registerFallbackValue(<String, dynamic>{});
      registerFallbackValue(Exception());
      registerFallbackValue(StackTrace.current);
    });

    group('onRequest', () {
      test('should log request when HTTP logging is enabled', () {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        when(
          () => mockLoggingService.debug(
            any(),
            context: any(named: 'context'),
          ),
        ).thenReturn(null);

        // Act
        interceptor.onRequest(requestOptions, handler);

        // Assert
        verify(
          () => mockLoggingService.debug(
            any(that: contains('API Request: GET /api/test')),
            context: any(named: 'context'),
          ),
        ).called(1);
      });

      test('should include method and path in log', () {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        when(
          () => mockLoggingService.debug(
            any(),
            context: any(named: 'context'),
          ),
        ).thenReturn(null);

        // Act
        interceptor.onRequest(requestOptions, handler);

        // Assert
        verify(
          () => mockLoggingService.debug(
            any(
              that: allOf(
                contains('GET'),
                contains('/api/test'),
              ),
            ),
            context: any(named: 'context'),
          ),
        ).called(1);
      });

      test('should sanitize sensitive headers', () {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        final optionsWithSensitiveHeaders = RequestOptions(
          path: '/api/test',
          method: 'GET',
          headers: {
            'authorization': 'Bearer secret-token',
            'cookie': 'session=abc123',
            'x-api-key': 'secret-key',
            'content-type': 'application/json',
          },
        );
        Map<String, dynamic>? capturedContext;
        when(
          () => mockLoggingService.debug(
            any(),
            context: any(named: 'context'),
          ),
        ).thenAnswer((invocation) {
          capturedContext =
              invocation.namedArguments[#context] as Map<String, dynamic>?;
          return;
        });

        // Act
        interceptor.onRequest(optionsWithSensitiveHeaders, handler);

        // Assert
        verify(
          () => mockLoggingService.debug(
            any(),
            context: any(named: 'context'),
          ),
        ).called(1);
        expect(capturedContext, isNotNull);
        expect(capturedContext!['headers'], isA<Map<String, dynamic>>());
        final headers = capturedContext!['headers'] as Map<String, dynamic>;
        expect(headers['authorization'], '***REDACTED***');
        expect(headers['cookie'], '***REDACTED***');
        expect(headers['x-api-key'], '***REDACTED***');
      });
      test('should include query parameters when present', () {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        final optionsWithQuery = RequestOptions(
          path: '/api/test',
          method: 'GET',
          queryParameters: {'page': '1', 'limit': '10'},
        );
        Map<String, dynamic>? capturedContext;
        when(
          () => mockLoggingService.debug(
            any(),
            context: any(named: 'context'),
          ),
        ).thenAnswer((invocation) {
          capturedContext =
              invocation.namedArguments[#context] as Map<String, dynamic>?;
          return;
        });

        // Act
        interceptor.onRequest(optionsWithQuery, handler);

        // Assert
        verify(
          () => mockLoggingService.debug(
            any(),
            context: any(named: 'context'),
          ),
        ).called(1);
        expect(capturedContext, isNotNull);
        expect(capturedContext!.containsKey('queryParameters'), isTrue);
      });

      test('should include body when present', () {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        final optionsWithBody = RequestOptions(
          path: '/api/test',
          method: 'POST',
          data: {'key': 'value'},
        );
        Map<String, dynamic>? capturedContext;
        when(
          () => mockLoggingService.debug(
            any(),
            context: any(named: 'context'),
          ),
        ).thenAnswer((invocation) {
          capturedContext =
              invocation.namedArguments[#context] as Map<String, dynamic>?;
          return;
        });

        // Act
        interceptor.onRequest(optionsWithBody, handler);

        // Assert
        verify(
          () => mockLoggingService.debug(
            any(),
            context: any(named: 'context'),
          ),
        ).called(1);
        expect(capturedContext, isNotNull);
        expect(capturedContext!.containsKey('body'), isTrue);
      });

      test('should not include body when null', () {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        final optionsWithoutBody = RequestOptions(
          path: '/api/test',
          method: 'GET',
        );
        Map<String, dynamic>? capturedContext;
        when(
          () => mockLoggingService.debug(
            any(),
            context: any(named: 'context'),
          ),
        ).thenAnswer((invocation) {
          capturedContext =
              invocation.namedArguments[#context] as Map<String, dynamic>?;
          return;
        });

        // Act
        interceptor.onRequest(
          optionsWithoutBody,
          handler,
        );

        // Assert
        verify(
          () => mockLoggingService.debug(
            any(),
            context: any(named: 'context'),
          ),
        ).called(1);
        expect(capturedContext, isNotNull);
        expect(capturedContext!.containsKey('body'), isFalse);
      });
    });

    group('onResponse', () {
      test('should log successful response', () {
        // Arrange
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 200,
          data: {'key': 'value'},
        );
        final handler = TestResponseInterceptorHandler();
        when(
          () => mockLoggingService.info(
            any(),
            context: any(named: 'context'),
          ),
        ).thenReturn(null);

        // Act
        interceptor.onResponse(response, handler);

        // Assert
        verify(
          () => mockLoggingService.info(
            any(that: contains('API Response: 200')),
            context: any(named: 'context'),
          ),
        ).called(1);
      });

      test('should log error response as warning', () {
        // Arrange
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 404,
          data: {'error': 'Not found'},
        );
        final handler = TestResponseInterceptorHandler();
        when(
          () => mockLoggingService.warning(
            any(),
            context: any(named: 'context'),
          ),
        ).thenReturn(null);

        // Act
        interceptor.onResponse(response, handler);

        // Assert
        verify(
          () => mockLoggingService.warning(
            any(that: contains('API Response: 404')),
            context: any(named: 'context'),
          ),
        ).called(1);
      });

      test('should log 4xx responses as warning', () {
        // Arrange
        final statusCodes = [400, 401, 403, 404, 422];
        for (final statusCode in statusCodes) {
          final response = Response<dynamic>(
            requestOptions: requestOptions,
            statusCode: statusCode,
          );
          final handler = TestResponseInterceptorHandler();
          when(
            () => mockLoggingService.warning(
              any(),
              context: any(named: 'context'),
            ),
          ).thenReturn(null);

          // Act
          interceptor.onResponse(response, handler);

          // Assert
          verify(
            () => mockLoggingService.warning(
              any(that: contains('API Response: $statusCode')),
              context: any(named: 'context'),
            ),
          ).called(1);
          clearInteractions(mockLoggingService);
        }
      });

      test('should include response data when present', () {
        // Arrange
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 200,
          data: {'result': 'success'},
        );
        final handler = TestResponseInterceptorHandler();
        Map<String, dynamic>? capturedContext;
        when(
          () => mockLoggingService.info(
            any(),
            context: any(named: 'context'),
          ),
        ).thenAnswer((invocation) {
          capturedContext =
              invocation.namedArguments[#context] as Map<String, dynamic>?;
          return;
        });

        // Act
        interceptor.onResponse(response, handler);

        // Assert
        verify(
          () => mockLoggingService.info(
            any(),
            context: any(named: 'context'),
          ),
        ).called(1);
        expect(capturedContext, isNotNull);
        expect(capturedContext!.containsKey('body'), isTrue);
      });
    });

    group('onError', () {
      test('should log error with details', () {
        // Arrange
        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionTimeout,
          message: 'Connection timeout',
        );
        final handler = TestErrorInterceptorHandler();
        when(
          () => mockLoggingService.error(
            any(),
            context: any(named: 'context'),
            error: any(named: 'error'),
            stackTrace: any(named: 'stackTrace'),
          ),
        ).thenReturn(null);

        // Act
        interceptor.onError(dioException, handler);

        // Assert
        verify(
          () => mockLoggingService.error(
            any(that: contains('API Error')),
            context: any(named: 'context'),
            error: dioException,
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);
      });

      test('should include error type in log', () {
        // Arrange
        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.connectionTimeout,
        );
        final handler = TestErrorInterceptorHandler();
        Map<String, dynamic>? capturedContext;
        when(
          () => mockLoggingService.error(
            any(),
            context: any(named: 'context'),
            error: any(named: 'error'),
            stackTrace: any(named: 'stackTrace'),
          ),
        ).thenAnswer((invocation) {
          capturedContext =
              invocation.namedArguments[#context] as Map<String, dynamic>?;
          return;
        });

        // Act
        interceptor.onError(dioException, handler);

        // Assert
        verify(
          () => mockLoggingService.error(
            any(),
            context: any(named: 'context'),
            error: any(named: 'error'),
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);
        expect(capturedContext, isNotNull);
        expect(capturedContext!.containsKey('type'), isTrue);
      });

      test('should include response status code when available', () {
        // Arrange
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
        Map<String, dynamic>? capturedContext;
        when(
          () => mockLoggingService.error(
            any(),
            context: any(named: 'context'),
            error: any(named: 'error'),
            stackTrace: any(named: 'stackTrace'),
          ),
        ).thenAnswer((invocation) {
          capturedContext =
              invocation.namedArguments[#context] as Map<String, dynamic>?;
          return;
        });

        // Act
        interceptor.onError(dioException, handler);

        // Assert
        verify(
          () => mockLoggingService.error(
            any(),
            context: any(named: 'context'),
            error: any(named: 'error'),
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);
        expect(capturedContext, isNotNull);
        expect(
          capturedContext!['statusCode'],
          500,
        );
      });

      test('should sanitize sensitive data in error response', () {
        // Arrange
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 400,
          data: {
            'password': 'secret123',
            'token': 'abc123',
            'message': 'Invalid credentials',
          },
        );
        final dioException = DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: response,
        );
        final handler = TestErrorInterceptorHandler();
        Map<String, dynamic>? capturedContext;
        when(
          () => mockLoggingService.error(
            any(),
            context: any(named: 'context'),
            error: any(named: 'error'),
            stackTrace: any(named: 'stackTrace'),
          ),
        ).thenAnswer((invocation) {
          capturedContext =
              invocation.namedArguments[#context] as Map<String, dynamic>?;
          return;
        });

        // Act
        interceptor.onError(dioException, handler);

        // Assert
        verify(
          () => mockLoggingService.error(
            any(),
            context: any(named: 'context'),
            error: any(named: 'error'),
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);
        expect(capturedContext, isNotNull);
        if (capturedContext!.containsKey('responseBody')) {
          final body = capturedContext!['responseBody'];
          if (body is Map) {
            expect(
              body['password'],
              '***REDACTED***',
            );
            expect(body['token'], '***REDACTED***');
          }
        }
      });
    });

    group('_sanitizeBody', () {
      test('should sanitize sensitive fields in JSON body', () {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        final options = RequestOptions(
          path: '/api/test',
          method: 'POST',
          data: {
            'username': 'user',
            'password': 'secret123',
            'token': 'abc123',
          },
        );
        Map<String, dynamic>? capturedContext;
        when(
          () => mockLoggingService.debug(
            any(),
            context: any(named: 'context'),
          ),
        ).thenAnswer((invocation) {
          capturedContext =
              invocation.namedArguments[#context] as Map<String, dynamic>?;
          return;
        });

        // Act
        interceptor.onRequest(options, handler);

        // Assert
        verify(
          () => mockLoggingService.debug(
            any(),
            context: any(named: 'context'),
          ),
        ).called(1);
        expect(capturedContext, isNotNull);
        if (capturedContext!.containsKey('body')) {
          final body = capturedContext!['body'] as Map;
          expect(body['password'], '***REDACTED***');
          expect(body['token'], '***REDACTED***');
          expect(
            body['username'],
            'user',
          );
        }
      });

      test('should sanitize nested sensitive fields', () {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        final options = RequestOptions(
          path: '/api/test',
          method: 'POST',
          data: {
            'user': {
              'name': 'John',
              'password': 'secret',
            },
            'token': 'abc123',
          },
        );
        Map<String, dynamic>? capturedContext;
        when(
          () => mockLoggingService.debug(
            any(),
            context: any(named: 'context'),
          ),
        ).thenAnswer((invocation) {
          capturedContext =
              invocation.namedArguments[#context] as Map<String, dynamic>?;
          return;
        });

        // Act
        interceptor.onRequest(options, handler);

        // Assert
        verify(
          () => mockLoggingService.debug(
            any(),
            context: any(named: 'context'),
          ),
        ).called(1);
        expect(capturedContext, isNotNull);
        if (capturedContext!.containsKey('body')) {
          final body = capturedContext!['body'] as Map;
          final user = body['user'] as Map;
          expect(user['password'], '***REDACTED***');
          expect(body['token'], '***REDACTED***');
        }
      });

      test('should handle string body', () {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        final options = RequestOptions(
          path: '/api/test',
          method: 'POST',
          data: '{"key": "value"}',
        );
        when(
          () => mockLoggingService.debug(
            any(),
            context: any(named: 'context'),
          ),
        ).thenReturn(null);

        // Act
        interceptor.onRequest(options, handler);

        // Assert
        verify(
          () => mockLoggingService.debug(
            any(),
            context: any(named: 'context'),
          ),
        ).called(1);
      });
    });
  });
}
