import 'package:dio/dio.dart';
import 'package:flutter_starter/core/network/interceptors/retry_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

class _FakeErrorHandler extends Fake implements ErrorInterceptorHandler {
  _FakeErrorHandler({
    required this.onResolve,
    required this.onReject,
    this.onNext,
  });

  final void Function(Response<dynamic> response) onResolve;
  final void Function(DioException err) onReject;
  final void Function(DioException err)? onNext;

  @override
  void resolve(Response<dynamic> response) => onResolve(response);

  @override
  void reject(DioException err) => onReject(err);

  @override
  void next(DioException err) => (onNext ?? (_) {})(err);
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      RequestOptions(path: '/'),
    );
    registerFallbackValue(
      Options(),
    );
  });

  group('RetryInterceptor', () {
    test('should retry transient errors and resolve on success', () async {
      final dio = _MockDio();
      final interceptor = RetryInterceptor(
        dio: dio,
        maxRetries: 1,
        initialExecutionDelay: Duration.zero,
      );

      final options = RequestOptions(path: '/x')..method = 'GET';
      final err = DioException(
        requestOptions: options,
        type: DioExceptionType.connectionTimeout,
      );

      final response = Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: {'ok': true},
      );

      when(
        () => dio.request<dynamic>(
          any(),
          data: any<dynamic>(named: 'data'),
          queryParameters: any<Map<String, dynamic>>(named: 'queryParameters'),
          cancelToken: any<CancelToken?>(named: 'cancelToken'),
          options: any<Options>(named: 'options'),
          onReceiveProgress: any<ProgressCallback?>(named: 'onReceiveProgress'),
          onSendProgress: any<ProgressCallback?>(named: 'onSendProgress'),
        ),
      ).thenAnswer((_) async => response);

      Response<dynamic>? resolved;
      DioException? rejected;
      final handler = _FakeErrorHandler(
        onResolve: (r) => resolved = r,
        onReject: (e) => rejected = e,
      );

      await interceptor.onError(err, handler);

      expect(rejected, isNull);
      expect(resolved, isNotNull);
      expect(resolved!.statusCode, 200);
      expect(options.extra['retry_count'], 1);
      verify(
        () => dio.request<dynamic>(
          '/x',
          data: any<dynamic>(named: 'data'),
          queryParameters: any<Map<String, dynamic>>(named: 'queryParameters'),
          cancelToken: any<CancelToken?>(named: 'cancelToken'),
          options: any<Options>(named: 'options'),
          onReceiveProgress: any<ProgressCallback?>(named: 'onReceiveProgress'),
          onSendProgress: any<ProgressCallback?>(named: 'onSendProgress'),
        ),
      ).called(1);
    });

    test('should not retry on 4xx badResponse', () async {
      final dio = _MockDio();
      final interceptor = RetryInterceptor(
        dio: dio,
        initialExecutionDelay: Duration.zero,
      );

      final options = RequestOptions(path: '/x')..method = 'GET';
      final err = DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: 401,
        ),
      );

      Response<dynamic>? resolved;
      DioException? rejected;
      DioException? nexted;
      final handler = _FakeErrorHandler(
        onResolve: (r) => resolved = r,
        onReject: (e) => rejected = e,
        onNext: (e) => nexted = e,
      );

      await interceptor.onError(err, handler);

      expect(resolved, isNull);
      expect(rejected, isNull); // forwarded to super, handler untouched
      expect(nexted, same(err));
      verifyNever(
        () => dio.request<dynamic>(
          any(),
          data: any<dynamic>(named: 'data'),
          queryParameters: any<Map<String, dynamic>>(named: 'queryParameters'),
          cancelToken: any<CancelToken?>(named: 'cancelToken'),
          options: any<Options>(named: 'options'),
          onReceiveProgress: any<ProgressCallback?>(named: 'onReceiveProgress'),
          onSendProgress: any<ProgressCallback?>(named: 'onSendProgress'),
        ),
      );
    });

    test('should not retry when retry_count reached maxRetries', () async {
      final dio = _MockDio();
      final interceptor = RetryInterceptor(
        dio: dio,
        maxRetries: 1,
        initialExecutionDelay: Duration.zero,
      );

      final options = RequestOptions(path: '/x')
        ..method = 'GET'
        ..extra['retry_count'] = 1;

      final err = DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );

      Response<dynamic>? resolved;
      DioException? rejected;
      DioException? nexted;
      final handler = _FakeErrorHandler(
        onResolve: (r) => resolved = r,
        onReject: (e) => rejected = e,
        onNext: (e) => nexted = e,
      );

      await interceptor.onError(err, handler);

      expect(resolved, isNull);
      expect(rejected, isNull);
      expect(nexted, same(err));
      verifyNever(
        () => dio.request<dynamic>(
          any(),
          data: any<dynamic>(named: 'data'),
          queryParameters: any<Map<String, dynamic>>(named: 'queryParameters'),
          cancelToken: any<CancelToken?>(named: 'cancelToken'),
          options: any<Options>(named: 'options'),
          onReceiveProgress: any<ProgressCallback?>(named: 'onReceiveProgress'),
          onSendProgress: any<ProgressCallback?>(named: 'onSendProgress'),
        ),
      );
    });

    test('should reject when retry attempt fails too', () async {
      final dio = _MockDio();
      final interceptor = RetryInterceptor(
        dio: dio,
        maxRetries: 1,
        initialExecutionDelay: Duration.zero,
      );

      final options = RequestOptions(path: '/x')..method = 'GET';
      final err = DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );

      final retryErr = DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );

      when(
        () => dio.request<dynamic>(
          any(),
          data: any<dynamic>(named: 'data'),
          queryParameters: any<Map<String, dynamic>>(named: 'queryParameters'),
          cancelToken: any<CancelToken?>(named: 'cancelToken'),
          options: any<Options>(named: 'options'),
          onReceiveProgress: any<ProgressCallback?>(named: 'onReceiveProgress'),
          onSendProgress: any<ProgressCallback?>(named: 'onSendProgress'),
        ),
      ).thenThrow(retryErr);

      Response<dynamic>? resolved;
      DioException? rejected;
      final handler = _FakeErrorHandler(
        onResolve: (r) => resolved = r,
        onReject: (e) => rejected = e,
      );

      await interceptor.onError(err, handler);

      expect(resolved, isNull);
      expect(rejected, same(retryErr));
      expect(options.extra['retry_count'], 1);
    });
  });

  // Regression cover for koniz-dev/flutter-starter#88.
  group('RetryInterceptor idempotency gate', () {
    late _MockDio dio;
    late RetryInterceptor interceptor;

    setUp(() {
      dio = _MockDio();
      interceptor = RetryInterceptor(
        dio: dio,
        maxRetries: 1,
        initialExecutionDelay: Duration.zero,
      );

      when(
        () => dio.request<dynamic>(
          any(),
          data: any<dynamic>(named: 'data'),
          queryParameters: any<Map<String, dynamic>>(named: 'queryParameters'),
          cancelToken: any<CancelToken?>(named: 'cancelToken'),
          options: any<Options>(named: 'options'),
          onReceiveProgress: any<ProgressCallback?>(named: 'onReceiveProgress'),
          onSendProgress: any<ProgressCallback?>(named: 'onSendProgress'),
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 200,
        ),
      );
    });

    /// Runs one error through the interceptor and reports whether it replayed.
    Future<bool> replayed(RequestOptions options, DioExceptionType type) async {
      final err = DioException(
        requestOptions: options,
        type: type,
        response: type == DioExceptionType.badResponse
            ? Response<dynamic>(requestOptions: options, statusCode: 503)
            : null,
      );

      var didResolve = false;
      await interceptor.onError(
        err,
        _FakeErrorHandler(
          onResolve: (_) => didResolve = true,
          onReject: (_) {},
          onNext: (_) {},
        ),
      );
      return didResolve;
    }

    for (final method in ['GET', 'HEAD', 'OPTIONS']) {
      test('$method is replayed on a 5xx', () async {
        final options = RequestOptions(path: '/x')..method = method;
        expect(
          await replayed(options, DioExceptionType.badResponse),
          isTrue,
        );
      });
    }

    for (final method in ['POST', 'PUT', 'PATCH', 'DELETE']) {
      test('$method is not replayed on receiveTimeout', () async {
        final options = RequestOptions(path: '/x')..method = method;
        expect(
          await replayed(options, DioExceptionType.receiveTimeout),
          isFalse,
        );
      });

      test('$method is not replayed on connectionError', () async {
        // A socket error can also be a reset after the body was delivered.
        final options = RequestOptions(path: '/x')..method = method;
        expect(
          await replayed(options, DioExceptionType.connectionError),
          isFalse,
        );
      });

      test('$method is replayed on connectionTimeout', () async {
        // The socket never connected, so no byte reached the server.
        final options = RequestOptions(path: '/x')..method = method;
        expect(
          await replayed(options, DioExceptionType.connectionTimeout),
          isTrue,
        );
      });
    }

    test('extra retry:true opts a POST into replay', () async {
      final options = RequestOptions(path: '/x')
        ..method = 'POST'
        ..extra[RetryInterceptor.retryExtraKey] = true;

      expect(await replayed(options, DioExceptionType.receiveTimeout), isTrue);
    });

    test('an Idempotency-Key header opts a POST into replay', () async {
      final options = RequestOptions(
        path: '/x',
        headers: <String, dynamic>{'idempotency-key': 'key-1'},
      )..method = 'POST';

      expect(await replayed(options, DioExceptionType.receiveTimeout), isTrue);
    });

    test('an empty Idempotency-Key header does not opt in', () async {
      final options = RequestOptions(
        path: '/x',
        headers: <String, dynamic>{RetryInterceptor.idempotencyKeyHeader: ''},
      )..method = 'POST';

      expect(await replayed(options, DioExceptionType.receiveTimeout), isFalse);
    });

    test('extra retry:false suppresses replay for a GET', () async {
      final options = RequestOptions(path: '/x')
        ..method = 'GET'
        ..extra[RetryInterceptor.retryExtraKey] = false;

      expect(await replayed(options, DioExceptionType.receiveTimeout), isFalse);
    });
  });
}
