// SecureStorageService.getString answers a failed Keychain read with null,
// the same as a missing token, and the token store read through it. So a
// transient read failure (iOS before first unlock) sent a request
// unauthenticated, its 401 found "no refresh token", and the user was signed
// out; and the cache's "fails closed when the store throws" branch could
// never run. The token store now reads strictly.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/contracts/state_boundary_contracts.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/cache_interceptor.dart';
import 'package:flutter_starter/core/storage/adapters/secure_token_store.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/in_memory_stores.dart';

class _MockSecureStorage extends Mock implements SecureStorageService {}

class _CountingSink implements ISessionTerminationSink {
  int calls = 0;

  @override
  void onSessionTerminated() => calls++;
}

class _ResponseHandler extends ResponseInterceptorHandler {}

/// Answers 200 to anything, recording the paths sent.
class _Adapter implements HttpClientAdapter {
  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
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

/// A Keychain whose reads fail, and which still holds both tokens.
_MockSecureStorage _lockedKeychain(Map<String, String> stored) {
  final storage = _MockSecureStorage();
  when(
    () => storage.getStringOrThrow(any()),
  ).thenThrow(Exception('errSecInteractionNotAllowed'));
  when(() => storage.getString(any())).thenAnswer((_) async => null);
  when(() => storage.remove(any())).thenAnswer((i) async {
    stored.remove(i.positionalArguments[0] as String);
    return true;
  });
  return storage;
}

void main() {
  test('a failed read is a CacheException, not a missing token', () async {
    final store = SecureTokenStore(_lockedKeychain({}));

    await expectLater(store.getAccessToken(), throwsA(isA<CacheException>()));
    await expectLater(store.getRefreshToken(), throwsA(isA<CacheException>()));
  });

  test('a request made while the Keychain cannot be read fails, and the '
      'session is kept', () async {
    final stored = {
      AppConstants.tokenKey: 'access',
      AppConstants.refreshTokenKey: 'refresh',
    };
    final sink = _CountingSink();
    final adapter = _Adapter();
    final client = ApiClient(
      storageService: InMemoryStorage(),
      secureStorageService: _MockSecureStorage(),
      authInterceptor: AuthInterceptor(
        tokenStore: SecureTokenStore(_lockedKeychain(stored)),
        sessionSink: sink,
        refreshToken: () => throw StateError('no refresh expected'),
      ),
    )..dio.httpClientAdapter = adapter;

    await expectLater(client.get('/me'), throwsA(isA<CacheException>()));

    expect(adapter.paths, isEmpty, reason: 'nothing sent unauthenticated');
    expect(sink.calls, 0, reason: 'session kept');
    expect(stored.keys, hasLength(2), reason: 'tokens not cleared');
  });

  test('the cache treats an unreadable token store as signed in', () async {
    final storage = InMemoryStorage();
    final cache = CacheInterceptor(
      storageService: storage,
      tokenStore: SecureTokenStore(_lockedKeychain({})),
    );
    final options = RequestOptions(
      path: '/catalog',
      method: 'GET',
      baseUrl: 'https://api.example.com',
    );

    await cache.onResponse(
      Response<dynamic>(requestOptions: options, statusCode: 200, data: 'x'),
      _ResponseHandler(),
    );

    expect(
      storage.values.keys.where((k) => k.startsWith('http_cache_')),
      isEmpty,
    );
  });
}
