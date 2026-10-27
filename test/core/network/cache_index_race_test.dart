// The cache index must list every cached key, even under concurrent GETs.
//
// _addToIndex read the index, appended and wrote it back with no
// serialization, so two cached GETs completing together each read the same
// old index and the last write dropped the other's key. clearCache() walks
// only the index, so that body survived the logout wipe. The
// store here makes list reads asynchronous, as a real one is.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/in_memory_stores.dart';

class _MockSecureStorageService extends Mock implements SecureStorageService {}

/// An in-memory store whose list reads take a moment, like a real one.
class _SlowListStorage extends InMemoryStorage {
  @override
  Future<List<String>?> getStringList(String key) async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return await super.getStringList(key);
  }
}

class _OkAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({'path': options.path}),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  late _SlowListStorage storage;
  late ApiClient client;

  setUp(() {
    storage = _SlowListStorage();
    client = ApiClient(
      storageService: storage,
      secureStorageService: _MockSecureStorageService(),
      // No token: anonymous GETs, which are the ones the cache stores.
      authInterceptor: AuthInterceptor(
        tokenStore: InMemoryTokenStore(),
        refreshToken: () async => const Success('unused'),
      ),
    )..dio.httpClientAdapter = _OkAdapter();
  });

  List<String> bodyKeys() => [
    for (final key in storage.values.keys)
      if (key.startsWith('http_cache_') &&
          !key.startsWith('http_cache_timestamp_') &&
          key != 'http_cache_index')
        key,
  ];

  test('criterion 1: concurrent cached GETs all land in the index', () async {
    await Future.wait([
      client.get('/a'),
      client.get('/b'),
      client.get('/c'),
      client.get('/d'),
    ]);

    final index = await storage.getStringList('http_cache_index');
    expect(bodyKeys(), hasLength(4));
    expect(index?.toSet(), bodyKeys().toSet());
  });

  test('criterion 2: after clearCache() no http_cache_* key remains', () async {
    await Future.wait([client.get('/a'), client.get('/b')]);
    expect(bodyKeys(), hasLength(2));

    await client.responseCache.clearCache();

    expect(
      storage.values.keys.where((k) => k.startsWith('http_cache_')),
      isEmpty,
    );
  });
}
