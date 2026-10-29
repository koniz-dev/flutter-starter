// A query key with malformed percent-encoding (`a%=1`, `%zz=1`) is a path
// Uri.parse accepts and dio sends. redactPath decoded every key and threw on
// these; PerformanceInterceptor redacts every request's path, so the request
// itself failed, in every build, before reaching the transport.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/api_logging_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/performance/noop_performance_service.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/in_memory_stores.dart';

class _MockSecureStorageService extends Mock implements SecureStorageService {}

class _OkAdapter implements HttpClientAdapter {
  final List<Uri> sent = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sent.add(options.uri);
    return ResponseBody.fromString(
      jsonEncode({'ok': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('redactPath', () {
    for (final path in [
      '/v?a%=1',
      '/v?%zz=1',
      '/v?x=1&b%=2',
      // Well-formed escapes that are not UTF-8, and raw non-ASCII: each made
      // Uri.decodeQueryComponent throw too.
      '/v?%E9=1',
      '/v?%FF=1',
      '/v?%C3=1',
      '/v?%D8%00=1',
      '/v?%ED%A0%80=1',
      '/v?café=1',
      '/v?\uD800=1',
    ]) {
      test('does not throw on $path', () {
        expect(() => ApiLoggingInterceptor.redactPath(path), returnsNormally);
      });
    }

    test('redacts the value of a key it cannot decode (fail closed)', () {
      final redacted = ApiLoggingInterceptor.redactPath(
        '/v?tok%zzen=SECRET&page=2',
      );

      expect(redacted, isNot(contains('SECRET')));
      expect(redacted, contains('page=2'));
    });

    for (final key in ['%74oken', 'To%6Ben', 'TOKEN', 'access+token']) {
      test('an escaped or re-cased sensitive key ($key) is still redacted', () {
        expect(
          ApiLoggingInterceptor.redactPath('/v?$key=SECRET'),
          isNot(contains('SECRET')),
        );
      });
    }

    test('a sensitive key with an invalid byte inside is still redacted', () {
      expect(
        ApiLoggingInterceptor.redactPath('/v?tok%E9en=SECRET&page=2'),
        allOf(isNot(contains('SECRET')), contains('page=2')),
      );
    });

    test('a non-ASCII key that names nothing sensitive is kept', () {
      expect(ApiLoggingInterceptor.redactPath('/v?café=1'), '/v?café=1');
    });

    test('a readable sensitive key is still redacted', () {
      expect(
        ApiLoggingInterceptor.redactPath('/v?token=SECRET'),
        isNot(contains('SECRET')),
      );
    });
  });

  // Wired as apiClientProvider wires it: the no-op performance service still
  // installs PerformanceInterceptor, which redacts every request's path.
  group('redactUrl', () {
    for (final (url, secret) in [
      ('wss://u:SECRET@h/s', 'SECRET'),
      ('wss://SECRET@h/s', 'SECRET'),
      ('wss://u:SECRET%2fx@h/s', 'SECRET'),
      ('wss://u:SECRETé@h/s', 'SECRET'),
      ('wss://u:SE@CRET@h/s', 'CRET'),
      ('wss://u:SECRET@h:443x/s?token=T0KEN', 'SECRET'),
      ('wss://h/s?token=T0KEN', 'T0KEN'),
    ]) {
      test('removes the secret from $url', () {
        expect(ApiLoggingInterceptor.redactUrl(url), isNot(contains(secret)));
      });
    }

    test('keeps a URL with nothing to redact as written', () {
      expect(
        ApiLoggingInterceptor.redactUrl('wss://h:8443/s?room=lobby#x'),
        'wss://h:8443/s?room=lobby#x',
      );
    });

    test('an @ after the authority is not userinfo', () {
      expect(
        ApiLoggingInterceptor.redactUrl('wss://h/s?mail=a@b.c'),
        'wss://h/s?mail=a@b.c',
      );
    });
  });

  group('through ApiClient, with logging off', () {
    for (final path in ['/v?a%=1', '/v?%zz=1', '/v?%E9=1', '/v?café=1']) {
      test('$path reaches the transport and succeeds', () async {
        final adapter = _OkAdapter();
        final client = ApiClient(
          storageService: InMemoryStorage(),
          secureStorageService: _MockSecureStorageService(),
          performanceService: NoOpPerformanceService(),
          authInterceptor: AuthInterceptor(
            tokenStore: InMemoryTokenStore(),
            refreshToken: () async => const Success('unused'),
          ),
        )..dio.httpClientAdapter = adapter;

        final response = await client.get(path);

        expect(response.statusCode, 200);
        expect(adapter.sent, hasLength(1));
        expect(
          client.dio.interceptors.map((i) => i.runtimeType.toString()),
          contains('PerformanceInterceptor'),
        );
      });
    }
  });
}
