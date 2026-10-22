// A secret in a path's query string must not reach the logs.
//
// ApiLoggingInterceptor redacted queryParameters but logged
// options.path verbatim, so `get('/auth/magic-link/verify?token=X')` - a
// normal call, since ApiClient takes a path - wrote X into the request,
// response and error entries, and RetryInterceptor's retry line. `jwt`, the
// token field Strapi returns, was not a redacted body key either.

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/network/interceptors/api_logging_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/retry_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

const _secret = 'MAGIC-SECRET';
const _path = '/auth/magic-link/verify?token=$_secret&lang=vi';

/// Records every logged message and context.
class _RecordingLoggingService extends LoggingService {
  _RecordingLoggingService() : super(enableLogging: false);

  final List<String> logged = [];

  void _add(String message, Map<String, dynamic>? context) =>
      logged.add('$message $context');

  @override
  void debug(String message, {Map<String, dynamic>? context}) =>
      _add(message, context);

  @override
  void info(String message, {Map<String, dynamic>? context}) =>
      _add(message, context);

  @override
  void warning(
    String message, {
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  }) => _add(message, context);

  @override
  void error(
    String message, {
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  }) => _add(message, context);
}

class _RequestHandler extends RequestInterceptorHandler {}

class _ResponseHandler extends ResponseInterceptorHandler {}

/// Swallows the error the interceptor passes on, so it does not surface as
/// an unhandled future error.
class _ErrorHandler extends ErrorInterceptorHandler {
  @override
  void next(DioException err) {}
}

void main() {
  late _RecordingLoggingService logging;
  late ApiLoggingInterceptor interceptor;
  final options = RequestOptions(path: _path, method: 'GET');

  setUp(() {
    logging = _RecordingLoggingService();
    interceptor = ApiLoggingInterceptor(loggingService: logging);
  });

  void expectRedacted() {
    final all = logging.logged.join('\n');
    expect(logging.logged, isNotEmpty);
    expect(all, isNot(contains(_secret)));
    expect(all, contains('token=***REDACTED***'));
    // An innocent parameter is kept.
    expect(all, contains('lang=vi'));
  }

  group('criterion 1: a ?token= in the path is redacted', () {
    test('in the request entry', () {
      interceptor.onRequest(options, _RequestHandler());
      expectRedacted();
    });

    test('in the response entry', () {
      interceptor.onResponse(
        Response<dynamic>(requestOptions: options, statusCode: 200),
        _ResponseHandler(),
      );
      expectRedacted();
    });

    test('in the error entry', () {
      interceptor.onError(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
        _ErrorHandler(),
      );
      expectRedacted();
    });

    test("in RetryInterceptor's retry line", () async {
      final retry = RetryInterceptor(
        dio: Dio(),
        loggingService: logging,
        initialExecutionDelay: Duration.zero,
        maxRetries: 1,
      );
      // An unreplayable body: the retry is declined, and the line saying so
      // carries the path - without sending anything.
      final unreplayable = RequestOptions(
        path: _path,
        method: 'GET',
        data: const Stream<List<int>>.empty(),
      );
      await retry.onError(
        DioException(
          requestOptions: unreplayable,
          type: DioExceptionType.connectionError,
        ),
        _ErrorHandler(),
      );
      final retryLines = logging.logged.where(
        (l) => l.startsWith('Not retrying'),
      );
      expect(retryLines, hasLength(1), reason: 'the retry line must be logged');
      expect(retryLines.single, isNot(contains(_secret)));
      expect(retryLines.single, contains('token=***REDACTED***'));
    });

    test('redactPath keeps everything but the secret as written', () {
      expect(
        ApiLoggingInterceptor.redactPath('/a?x=1&access_token=T#frag'),
        '/a?x=1&access_token=***REDACTED***#frag',
      );
      expect(ApiLoggingInterceptor.redactPath('/plain/path'), '/plain/path');
      expect(ApiLoggingInterceptor.redactPath('/a?flag'), '/a?flag');
    });
  });

  test('criterion 2: a response body key jwt is redacted', () {
    interceptor.onResponse(
      Response<dynamic>(
        requestOptions: RequestOptions(path: '/auth/local', method: 'POST'),
        statusCode: 200,
        data: {'jwt': 'STRAPI-JWT', 'user': 'u'},
      ),
      _ResponseHandler(),
    );

    final all = logging.logged.join('\n');
    expect(all, isNot(contains('STRAPI-JWT')));
    expect(all, contains('user: u'));
  });
}
