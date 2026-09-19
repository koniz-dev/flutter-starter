import 'dart:convert';

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
      interceptor = ApiLoggingInterceptor(loggingService: mockLoggingService);
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
          () => mockLoggingService.debug(any(), context: any(named: 'context')),
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
          () => mockLoggingService.debug(any(), context: any(named: 'context')),
        ).thenReturn(null);

        // Act
        interceptor.onRequest(requestOptions, handler);

        // Assert
        verify(
          () => mockLoggingService.debug(
            any(that: allOf(contains('GET'), contains('/api/test'))),
            context: any(named: 'context'),
          ),
        ).called(1);
      });

      test('should sanitize sensitive headers written the way production '
          'writes them', () {
        // Arrange. Headers go through dio's own RequestOptions, whose setter
        // wraps them in caseInsensitiveKeyMap - a map that compares keys
        // case-insensitively but stores them exactly as written.
        // AuthInterceptor writes `options.headers['Authorization']`, so the
        // capitalised spelling below is the one production actually produces.
        final handler = TestRequestInterceptorHandler();
        final optionsWithSensitiveHeaders = RequestOptions(
          path: '/api/test',
          method: 'GET',
          headers: <String, dynamic>{'Content-Type': 'application/json'},
        );
        optionsWithSensitiveHeaders.headers['Authorization'] =
            'Bearer secret-token';
        optionsWithSensitiveHeaders.headers['Cookie'] = 'session=abc123';
        optionsWithSensitiveHeaders.headers['X-Api-Key'] = 'secret-key';
        Map<String, dynamic>? capturedContext;
        when(
          () => mockLoggingService.debug(any(), context: any(named: 'context')),
        ).thenAnswer((invocation) {
          capturedContext =
              invocation.namedArguments[#context] as Map<String, dynamic>?;
          return;
        });

        // Act
        interceptor.onRequest(optionsWithSensitiveHeaders, handler);

        // Assert
        verify(
          () => mockLoggingService.debug(any(), context: any(named: 'context')),
        ).called(1);
        expect(capturedContext, isNotNull);
        expect(capturedContext!['headers'], isA<Map<String, dynamic>>());
        final headers = capturedContext!['headers'] as Map<String, dynamic>;
        expect(headers['Authorization'], '***REDACTED***');
        expect(headers['Cookie'], '***REDACTED***');
        expect(headers['X-Api-Key'], '***REDACTED***');
        expect(headers['Content-Type'], 'application/json');
      });

      test('should sanitize sensitive headers regardless of casing', () {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        final options = RequestOptions(
          path: '/api/test',
          method: 'GET',
          headers: <String, dynamic>{
            'AUTHORIZATION': 'Bearer secret-token',
            'cOoKiE': 'session=abc123',
            'x-API-key': 'secret-key',
          },
        );
        Map<String, dynamic>? capturedContext;
        when(
          () => mockLoggingService.debug(any(), context: any(named: 'context')),
        ).thenAnswer((invocation) {
          capturedContext =
              invocation.namedArguments[#context] as Map<String, dynamic>?;
          return;
        });

        // Act
        interceptor.onRequest(options, handler);

        // Assert
        final headers = capturedContext!['headers'] as Map<String, dynamic>;
        expect(headers['AUTHORIZATION'], '***REDACTED***');
        expect(headers['cOoKiE'], '***REDACTED***');
        expect(headers['x-API-key'], '***REDACTED***');
      });

      test('should leave no secret anywhere in the logged context for an '
          'authenticated request', () {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        final options = RequestOptions(path: '/api/test', method: 'POST');
        options.headers['Authorization'] =
            'Bearer eyJhbGciOi.REAL_USER_JWT.sig';
        options.headers['Cookie'] = 'session=abc123';
        options.headers['X-Api-Key'] = 'secret-key';
        Map<String, dynamic>? capturedContext;
        when(
          () => mockLoggingService.debug(any(), context: any(named: 'context')),
        ).thenAnswer((invocation) {
          capturedContext =
              invocation.namedArguments[#context] as Map<String, dynamic>?;
          return;
        });

        // Act
        interceptor.onRequest(options, handler);

        // Assert
        final rendered = capturedContext.toString();
        expect(rendered, isNot(contains('Bearer ')));
        expect(rendered, isNot(contains('REAL_USER_JWT')));
        expect(rendered, isNot(contains('abc123')));
        expect(rendered, isNot(contains('secret-key')));
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
          () => mockLoggingService.debug(any(), context: any(named: 'context')),
        ).thenAnswer((invocation) {
          capturedContext =
              invocation.namedArguments[#context] as Map<String, dynamic>?;
          return;
        });

        // Act
        interceptor.onRequest(optionsWithQuery, handler);

        // Assert
        verify(
          () => mockLoggingService.debug(any(), context: any(named: 'context')),
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
          () => mockLoggingService.debug(any(), context: any(named: 'context')),
        ).thenAnswer((invocation) {
          capturedContext =
              invocation.namedArguments[#context] as Map<String, dynamic>?;
          return;
        });

        // Act
        interceptor.onRequest(optionsWithBody, handler);

        // Assert
        verify(
          () => mockLoggingService.debug(any(), context: any(named: 'context')),
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
          () => mockLoggingService.debug(any(), context: any(named: 'context')),
        ).thenAnswer((invocation) {
          capturedContext =
              invocation.namedArguments[#context] as Map<String, dynamic>?;
          return;
        });

        // Act
        interceptor.onRequest(optionsWithoutBody, handler);

        // Assert
        verify(
          () => mockLoggingService.debug(any(), context: any(named: 'context')),
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
          () => mockLoggingService.info(any(), context: any(named: 'context')),
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
          () =>
              mockLoggingService.warning(any(), context: any(named: 'context')),
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
          () => mockLoggingService.info(any(), context: any(named: 'context')),
        ).thenAnswer((invocation) {
          capturedContext =
              invocation.namedArguments[#context] as Map<String, dynamic>?;
          return;
        });

        // Act
        interceptor.onResponse(response, handler);

        // Assert
        verify(
          () => mockLoggingService.info(any(), context: any(named: 'context')),
        ).called(1);
        expect(capturedContext, isNotNull);
        expect(capturedContext!.containsKey('body'), isTrue);
      });

      test('should redact Set-Cookie in the response header log', () {
        // Arrange. dio builds response headers through Headers.fromMap, which
        // is the same case-insensitive map used for requests.
        final response = Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 200,
          headers: Headers.fromMap(<String, List<String>>{
            'Set-Cookie': ['session=abc123; HttpOnly'],
            'Authorization': ['Bearer secret-token'],
            'Content-Type': ['application/json'],
          }, preserveHeaderCase: true),
        );
        final handler = TestResponseInterceptorHandler();
        Map<String, dynamic>? capturedContext;
        when(
          () => mockLoggingService.info(any(), context: any(named: 'context')),
        ).thenAnswer((invocation) {
          capturedContext =
              invocation.namedArguments[#context] as Map<String, dynamic>?;
          return;
        });

        // Act
        interceptor.onResponse(response, handler);

        // Assert
        expect(capturedContext, isNotNull);
        final headers = capturedContext!['headers'] as Map<String, dynamic>;
        expect(headers['Set-Cookie'], '***REDACTED***');
        expect(headers['Authorization'], '***REDACTED***');
        expect(headers['Content-Type'], <String>['application/json']);
        final rendered = capturedContext.toString();
        expect(rendered, isNot(contains('abc123')));
        expect(rendered, isNot(contains('Bearer ')));
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
        expect(capturedContext!['statusCode'], 500);
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
            expect(body['password'], '***REDACTED***');
            expect(body['token'], '***REDACTED***');
          }
        }
      });
    });

    /// Refs koniz-dev/flutter-starter#78.
    ///
    /// Every test here asserts on what the LoggingService actually received,
    /// and every secret literal is one that must not survive into any sink.
    group('secret redaction', () {
      Map<String, dynamic>? captureRequest(RequestOptions options) {
        Map<String, dynamic>? captured;
        when(
          () => mockLoggingService.debug(any(), context: any(named: 'context')),
        ).thenAnswer((invocation) {
          captured =
              invocation.namedArguments[#context] as Map<String, dynamic>?;
          return;
        });
        interceptor.onRequest(options, TestRequestInterceptorHandler());
        return captured;
      }

      Map<String, dynamic>? captureError(DioException err) {
        Map<String, dynamic>? captured;
        when(
          () => mockLoggingService.error(
            any(),
            context: any(named: 'context'),
            error: any(named: 'error'),
            stackTrace: any(named: 'stackTrace'),
          ),
        ).thenAnswer((invocation) {
          captured =
              invocation.namedArguments[#context] as Map<String, dynamic>?;
          return;
        });
        interceptor.onError(err, TestErrorInterceptorHandler());
        return captured;
      }

      // Criterion 1: a String body holding JSON is parsed and sanitized.
      test('sanitizes a pre-encoded JSON string body field by field', () {
        // Arrange. jsonEncode is the standard way to control encoding, and it
        // is exactly the shape _sanitizeBody used to log verbatim.
        const encoded = '{"email":"a@b.c","password":"hunter2"}';
        final options = RequestOptions(
          path: '/api/auth/login',
          method: 'POST',
          data: jsonEncode(<String, String>{
            'email': 'a@b.c',
            'password': 'hunter2',
          }),
        );

        // Act
        final context = captureRequest(options);

        // Assert
        expect(context, isNotNull);
        final rendered = context.toString();
        expect(rendered, isNot(contains('hunter2')));
        expect(rendered, isNot(contains(encoded)));
        expect(rendered, contains('***REDACTED***'));
        final body = context!['body'] as Map<String, dynamic>;
        expect(body['password'], '***REDACTED***');
        expect(body['email'], 'a@b.c');
      });

      // Criterion 2: pins the behavior for a String body that is not JSON.
      // The decision is redacted wholesale, not passed through: a form-encoded
      // body is a credential carrier and there is no key structure left to
      // judge once parsing has failed.
      test('redacts a form-encoded string body wholesale', () {
        // Arrange
        final options = RequestOptions(
          path: '/oauth/token',
          method: 'POST',
          data: 'grant_type=password&username=a%40b.c&password=hunter2',
        );

        // Act
        final context = captureRequest(options);

        // Assert
        expect(context!['body'], '***REDACTED***');
        expect(context.toString(), isNot(contains('hunter2')));
        expect(context.toString(), isNot(contains('grant_type')));
        // Redacted, not dropped: the key survives so a reader can tell a body
        // existed and was withheld.
        expect(context.containsKey('body'), isTrue);
      });

      test('redacts a plain-text string body wholesale', () {
        // Arrange
        final options = RequestOptions(
          path: '/api/test',
          method: 'POST',
          data: '502 Bad Gateway',
        );

        // Act
        final context = captureRequest(options);

        // Assert
        expect(context!['body'], '***REDACTED***');
      });

      test('redacts a bare JSON scalar string body, which has no key to '
          'judge by', () {
        // Arrange. jsonEncode of a naked token parses cleanly as JSON, so a
        // decode-then-sanitize rule that trusts any parse result leaks it.
        final options = RequestOptions(
          path: '/api/auth/refresh',
          method: 'POST',
          data: jsonEncode('rt_live_9f3c2b1a'),
        );

        // Act
        final context = captureRequest(options);

        // Assert
        expect(context!['body'], '***REDACTED***');
        expect(context.toString(), isNot(contains('rt_live_9f3c2b1a')));
      });

      test('sanitizes a top-level JSON array body', () {
        // Arrange
        final options = RequestOptions(
          path: '/api/batch',
          method: 'POST',
          data: jsonEncode(<Map<String, String>>[
            {'user': 'a', 'password': 'hunter2'},
            {'user': 'b', 'access_token': 'at_live_1'},
          ]),
        );

        // Act
        final context = captureRequest(options);

        // Assert
        final rendered = context.toString();
        expect(rendered, isNot(contains('hunter2')));
        expect(rendered, isNot(contains('at_live_1')));
        expect(rendered, contains('***REDACTED***'));
        expect(rendered, contains('user'));
      });

      test('redacts a body shape it cannot walk, such as FormData', () {
        // Arrange. A multipart login form carries the password in
        // FormData.fields, which no key walk of ours can reach.
        final options = RequestOptions(
          path: '/api/auth/login',
          method: 'POST',
          data: FormData.fromMap(<String, dynamic>{
            'email': 'a@b.c',
            'password': 'hunter2',
          }),
        );

        // Act
        final context = captureRequest(options);

        // Assert
        expect(context!['body'], '***REDACTED***');
        expect(context.toString(), isNot(contains('hunter2')));
      });

      // Criterion 3: query parameters obey the same rules as bodies.
      test('sanitizes query parameters by the same rules as bodies', () {
        // Arrange
        final options = RequestOptions(
          path: '/api/password-reset',
          method: 'GET',
          queryParameters: <String, dynamic>{
            'reset_token': 'abc123',
            'page': '2',
          },
        );

        // Act
        final context = captureRequest(options);

        // Assert
        final rendered = context.toString();
        expect(rendered, isNot(contains('abc123')));
        final query = context!['queryParameters'] as Map<String, dynamic>;
        expect(query['reset_token'], '***REDACTED***');
        expect(query['page'], '2');
      });

      test('sanitizes the query parameters conventionally used to carry '
          'credentials', () {
        // Arrange
        final options = RequestOptions(
          path: '/oauth/callback',
          method: 'GET',
          queryParameters: <String, dynamic>{
            'access_token': 'at_live_1',
            'api_key': 'ak_live_2',
            'signature': 'sig_live_3',
            'state': 'xyz',
          },
        );

        // Act
        final context = captureRequest(options);

        // Assert
        final query = context!['queryParameters'] as Map<String, dynamic>;
        expect(query['access_token'], '***REDACTED***');
        expect(query['api_key'], '***REDACTED***');
        expect(query['signature'], '***REDACTED***');
        expect(query['state'], 'xyz');
        final rendered = context.toString();
        expect(rendered, isNot(contains('at_live_1')));
        expect(rendered, isNot(contains('ak_live_2')));
        expect(rendered, isNot(contains('sig_live_3')));
      });

      // Criterion 4: the header roster covers the standard credential headers,
      // driven through dio's own RequestOptions in mixed casing.
      test('redacts proxy-authorization, x-auth-token, x-refresh-token and '
          'api-key in mixed casing', () {
        // Arrange
        final options = RequestOptions(path: '/api/test', method: 'GET');
        options.headers['Proxy-Authorization'] = 'Basic cHJveHk6c2VjcmV0';
        options.headers['X-Auth-Token'] = 'xat_live_1';
        options.headers['x-REFRESH-token'] = 'xrt_live_2';
        options.headers['Api-Key'] = 'ak_live_3';
        options.headers['X-Csrf-Token'] = 'csrf_live_4';
        options.headers['Content-Type'] = 'application/json';

        // Act
        final context = captureRequest(options);

        // Assert
        final headers = context!['headers'] as Map<String, dynamic>;
        expect(headers['Proxy-Authorization'], '***REDACTED***');
        expect(headers['X-Auth-Token'], '***REDACTED***');
        expect(headers['x-REFRESH-token'], '***REDACTED***');
        expect(headers['Api-Key'], '***REDACTED***');
        expect(headers['X-Csrf-Token'], '***REDACTED***');
        expect(headers['Content-Type'], 'application/json');
        final rendered = context.toString();
        expect(rendered, isNot(contains('cHJveHk6c2VjcmV0')));
        expect(rendered, isNot(contains('xat_live_1')));
        expect(rendered, isNot(contains('xrt_live_2')));
        expect(rendered, isNot(contains('ak_live_3')));
        expect(rendered, isNot(contains('csrf_live_4')));
      });

      // Criterion 5: the error path, live for the first time since 8a73fd2.
      test('leaves no secret in the error context for a failed login with a '
          'string request body and a string response body', () {
        // Arrange. Before 8a73fd2 ErrorInterceptor rejected first and this
        // code never ran; it now runs on every DioException.
        final failedLogin = RequestOptions(
          path: '/api/auth/login',
          method: 'POST',
          data: jsonEncode(<String, String>{
            'email': 'a@b.c',
            'password': 'hunter2',
          }),
        );
        final err = DioException(
          requestOptions: failedLogin,
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: failedLogin,
            statusCode: 401,
            data: jsonEncode(<String, String>{
              'error': 'invalid_grant',
              'refresh_token': 'rt_live_9f3c2b1a',
            }),
          ),
        );

        // Act
        final context = captureError(err);

        // Assert
        expect(context, isNotNull);
        final rendered = context.toString();
        expect(rendered, isNot(contains('hunter2')));
        expect(rendered, isNot(contains('rt_live_9f3c2b1a')));
        final requestBody = context!['requestBody'] as Map<String, dynamic>;
        expect(requestBody['password'], '***REDACTED***');
        expect(requestBody['email'], 'a@b.c');
        final responseBody = context['responseBody'] as Map<String, dynamic>;
        expect(responseBody['refresh_token'], '***REDACTED***');
        expect(responseBody['error'], 'invalid_grant');
        expect(context['statusCode'], 401);
      });

      test('leaves no secret in the error context when the bodies are not '
          'JSON', () {
        // Arrange
        final options = RequestOptions(
          path: '/api/auth/refresh',
          method: 'POST',
          data: 'refresh_token=rt_live_9f3c2b1a',
        );
        final err = DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: options,
            statusCode: 401,
            data: 'access_token=at_live_7&expires_in=3600',
          ),
        );

        // Act
        final context = captureError(err);

        // Assert
        expect(context!['requestBody'], '***REDACTED***');
        expect(context['responseBody'], '***REDACTED***');
        final rendered = context.toString();
        expect(rendered, isNot(contains('rt_live_9f3c2b1a')));
        expect(rendered, isNot(contains('at_live_7')));
      });

      // The cost of the rule, pinned so it cannot regress silently: matching
      // is on key names only, and short keys match exactly so that innocent
      // fields stay readable.
      test('does not redact innocent fields whose names merely contain a '
          'short secret key', () {
        // Arrange
        final options = RequestOptions(
          path: '/api/orders',
          method: 'POST',
          data: <String, dynamic>{
            'shipping': 'express',
            'author': 'jane',
            'description': 'a pin badge',
            'pin': '4321',
            'session': 'sess_live_1',
          },
        );

        // Act
        final context = captureRequest(options);

        // Assert
        final body = context!['body'] as Map<String, dynamic>;
        expect(body['shipping'], 'express');
        expect(body['author'], 'jane');
        expect(body['description'], 'a pin badge');
        expect(body['pin'], '***REDACTED***');
        expect(body['session'], '***REDACTED***');
      });

      test('decides by key name, not value shape, so a token under an '
          'unlisted key is still logged', () {
        // Arrange. This pins the accepted trade-off rather than a bug:
        // value-shape matching would catch this, but it would also redact
        // legitimate opaque ids and make the rule unpredictable.
        final options = RequestOptions(
          path: '/api/test',
          method: 'POST',
          data: <String, dynamic>{'blob': 'eyJhbGciOiJIUzI1NiJ9.payload.sig'},
        );

        // Act
        final context = captureRequest(options);

        // Assert
        final body = context!['body'] as Map<String, dynamic>;
        expect(body['blob'], 'eyJhbGciOiJIUzI1NiJ9.payload.sig');
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
          () => mockLoggingService.debug(any(), context: any(named: 'context')),
        ).thenAnswer((invocation) {
          capturedContext =
              invocation.namedArguments[#context] as Map<String, dynamic>?;
          return;
        });

        // Act
        interceptor.onRequest(options, handler);

        // Assert
        verify(
          () => mockLoggingService.debug(any(), context: any(named: 'context')),
        ).called(1);
        expect(capturedContext, isNotNull);
        if (capturedContext!.containsKey('body')) {
          final body = capturedContext!['body'] as Map;
          expect(body['password'], '***REDACTED***');
          expect(body['token'], '***REDACTED***');
          expect(body['username'], 'user');
        }
      });

      test('should sanitize nested sensitive fields', () {
        // Arrange
        final handler = TestRequestInterceptorHandler();
        final options = RequestOptions(
          path: '/api/test',
          method: 'POST',
          data: {
            'user': {'name': 'John', 'password': 'secret'},
            'token': 'abc123',
          },
        );
        Map<String, dynamic>? capturedContext;
        when(
          () => mockLoggingService.debug(any(), context: any(named: 'context')),
        ).thenAnswer((invocation) {
          capturedContext =
              invocation.namedArguments[#context] as Map<String, dynamic>?;
          return;
        });

        // Act
        interceptor.onRequest(options, handler);

        // Assert
        verify(
          () => mockLoggingService.debug(any(), context: any(named: 'context')),
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
          () => mockLoggingService.debug(any(), context: any(named: 'context')),
        ).thenReturn(null);

        // Act
        interceptor.onRequest(options, handler);

        // Assert
        verify(
          () => mockLoggingService.debug(any(), context: any(named: 'context')),
        ).called(1);
      });
    });
  });
}
