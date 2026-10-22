// Pinning on Flutter web.
//
// A browser owns TLS: there is no SecurityContext and no HttpClient, so an app
// cannot pin a certificate there at all. `SslPinning.createAdapter()` used to
// build an IOHttpClientAdapter anyway, and the first request threw
// `Unsupported operation: SecurityContext constructor` - with pinning on by
// default in staging and production, a web build configured with fingerprints
// for mobile sent no request at all.
//
// Run with: flutter test --platform chrome test/core/network/ssl_pinning_web_test.dart
// `@TestOn('browser')` skips it on the VM, where ssl_pinning_test.dart covers
// the pinned adapter.
@TestOn('browser')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/network/ssl_pinning.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorageService extends Mock implements StorageService {}

class _MockSecureStorageService extends Mock implements SecureStorageService {}

class _NoTokenStore implements ITokenStore {
  @override
  Future<void> clearAccessToken() async {}

  @override
  Future<void> clearAllTokens() async {}

  @override
  Future<void> clearRefreshToken() async {}

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<bool> setAccessToken(String token) async => true;

  @override
  Future<bool> setRefreshToken(String token) async => true;
}

/// Answers every request with `{"ok": true}` and records what it was sent.
class _FakeTransport implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
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

const _pinned = SslPinning(
  enabled: true,
  fingerprints: [
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
  ],
);

void main() {
  test('createAdapter builds no IO adapter on web', () {
    expect(_pinned.createAdapter(), isNull);
    expect(
      _pinned.isEffective,
      isFalse,
      reason: 'nothing is pinned on web, so the policy must not claim it is',
    );
  });

  test('a misconfigured policy does not assert on web either', () {
    // On native an enabled policy without fingerprints trips an assertion.
    // On web pinning does not apply at all, so there is nothing to
    // misconfigure.
    const policy = SslPinning(enabled: true, fingerprints: []);

    expect(policy.createAdapter, returnsNormally);
    expect(policy.createAdapter(), isNull);
  });

  test('ApiClient with pinning requested keeps the browser transport, and a '
      'request reaches it', () async {
    final client = ApiClient(
      storageService: _MockStorageService(),
      secureStorageService: _MockSecureStorageService(),
      authInterceptor: AuthInterceptor(
        tokenStore: _NoTokenStore(),
        refreshToken: () async => const Success<String>('unused'),
      ),
      sslPinning: _pinned,
    );

    expect(
      client.dio.httpClientAdapter,
      isNot(isA<IOHttpClientAdapter>()),
      reason: 'dart:io transport cannot run in a browser',
    );

    final transport = _FakeTransport();
    client.dio.httpClientAdapter = transport;
    final response = await client.dio.post<Map<String, dynamic>>('/ping');

    expect(response.data, {'ok': true});
    expect(transport.requests.single.path, '/ping');
  });
}
