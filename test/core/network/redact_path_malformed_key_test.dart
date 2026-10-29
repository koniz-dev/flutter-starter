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
    for (final path in ['/v?a%=1', '/v?%zz=1', '/v?x=1&b%=2']) {
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

    test('a readable sensitive key is still redacted', () {
      expect(
        ApiLoggingInterceptor.redactPath('/v?token=SECRET'),
        isNot(contains('SECRET')),
      );
    });
  });

  // Wired as apiClientProvider wires it: the no-op performance service still
  // installs PerformanceInterceptor, which redacts every request's path.
  group('through ApiClient, with logging off', () {
    for (final path in ['/v?a%=1', '/v?%zz=1']) {
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
