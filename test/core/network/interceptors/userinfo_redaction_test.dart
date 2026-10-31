// Userinfo in a URL is a credential: dart:io sends it as Basic auth. The
// logged baseUrl was not redacted at all, redactPath (used by the retry log
// lines and the performance trace) leaves an absolute URL's userinfo alone,
// and redactUrl's authority pattern missed a URL with leading whitespace.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/network/interceptors/api_logging_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/retry_interceptor.dart';
import 'package:flutter_starter/core/network/realtime/raw_websocket_client.dart';
import 'package:flutter_starter/core/network/ssl_pinning.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLogging extends Mock implements LoggingService {}

class _RequestHandler extends RequestInterceptorHandler {}

/// Passes the error on, as dio's handler does, without leaving the future
/// it completes unobserved.
class _ErrorHandler extends ErrorInterceptorHandler {
  _ErrorHandler() {
    unawaited(future.then((_) {}, onError: (_) {}));
  }
}

const _credentials = ['usrX', 'pwY'];

void _expectNoCredentials(String text) {
  for (final secret in _credentials) {
    expect(text, isNot(contains(secret)), reason: secret);
  }
}

void main() {
  late _MockLogging logging;
  late List<String> logged;

  setUp(() {
    logging = _MockLogging();
    logged = [];
    when(
      () => logging.debug(any(), context: any(named: 'context')),
    ).thenAnswer((i) {
      logged.add('${i.positionalArguments[0]} ${i.namedArguments[#context]}');
    });
  });

  test(
    'the request entry redacts userinfo in baseUrl and an absolute path',
    () {
      ApiLoggingInterceptor(loggingService: logging).onRequest(
        RequestOptions(
          baseUrl: 'https://usrX:pwY@api.example.com',
          path: 'https://usrX:pwY@other.example.com/x?page=1',
        ),
        _RequestHandler(),
      );

      final text = logged.join('\n');
      _expectNoCredentials(text);
      expect(text, contains('api.example.com'));
      expect(text, contains('page=1'));
    },
  );

  test('the retry log line redacts an absolute URL with userinfo', () async {
    final options = RequestOptions(
      path: 'https://usrX:pwY@api.example.com/upload',
      method: 'GET',
      // A stream cannot be replayed, so the interceptor logs and gives up.
      data: Stream<List<int>>.fromIterable(const []),
    );

    final handler = _ErrorHandler();
    await RetryInterceptor(dio: Dio(), loggingService: logging).onError(
      DioException(
        requestOptions: options,
        type: DioExceptionType.connectionTimeout,
      ),
      handler,
    );

    expect(logged, isNotEmpty);
    _expectNoCredentials(logged.join('\n'));
  });

  test('redactUrl removes userinfo after leading whitespace', () {
    final text = ApiLoggingInterceptor.redactUrl(' wss://usrX:pwY@h.example/x');
    _expectNoCredentials(text);
    expect(text, contains('h.example'));
  });

  test(
    'a realtime URL with leading whitespace fails without its userinfo',
    () async {
      Object? error;
      try {
        await RawWebSocketClientImpl(
          sslPinning: const SslPinning(enabled: false, fingerprints: []),
        ).connect(' wss://usrX:pwY@h.example/x');
      } on Object catch (e) {
        error = e;
      }
      expect(error, isNotNull);
      _expectNoCredentials('$error');
    },
  );
}
