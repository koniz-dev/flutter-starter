import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/constants/api_endpoints.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/cache_interceptor.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/in_memory_stores.dart';

class _SecureService extends Mock implements SecureStorageService {}

class _RejectDeletionStorage extends InMemoryStorage {
  bool reject = true;

  @override
  Future<bool> remove(String key) async {
    if (reject && key.startsWith('http_cache_')) return false;
    return await super.remove(key);
  }
}

class _RejectBodyWriteStorage extends InMemoryStorage {
  @override
  Future<bool> setString(String key, String value) async {
    if (key.startsWith('http_cache_') &&
        !key.startsWith('http_cache_timestamp_')) {
      return false;
    }
    return await super.setString(key, value);
  }
}

class _Transport implements HttpClientAdapter {
  _Transport(this.vary);
  final List<String> vary;
  int hits = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({'hit': ++hits}),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      if (vary.isNotEmpty) 'vary': vary,
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  late InMemoryStorage storage;
  late _Transport transport;

  ApiClient build({List<String> vary = const []}) {
    transport = _Transport(vary);
    return ApiClient(
      storageService: storage,
      secureStorageService: _SecureService(),
      authInterceptor: AuthInterceptor(
        tokenStore: InMemoryTokenStore(),
        refreshToken: () async => const Success('unused'),
      ),
    )..dio.httpClientAdapter = transport;
  }

  setUp(() => storage = InMemoryStorage());

  String seedPreviousPolicy() {
    final key = CacheInterceptor.cacheKeyFor(
      RequestOptions(
        path: '/profile',
        baseUrl: AppConfig.baseUrl + ApiEndpoints.apiVersion,
      ),
    );
    storage.values
      ..[key] = jsonEncode({'private': 'old-user'})
      ..['http_cache_timestamp_$key'] = DateTime.now().toUtc().toIso8601String()
      ..['http_cache_index'] = [key]
      ..['cache_rule_version'] = 2; // Previous query-only admission policy.
    return key;
  }

  for (final header in [
    'X-Api-Key',
    'Authorization',
    'X-Auth-Token',
    'Proxy-Authorization',
    'Cookie',
    'Set-Cookie',
    'Api-Key',
    'X-Refresh-Token',
    'X-Csrf-Token',
    'x_CUSTOM_session_key',
  ]) {
    test(
      '$header bypasses cache reads and writes across credentials',
      () async {
        final client = build();
        final first = await client.get('/profile', headers: {header: 'user-A'});
        final second = await client.get(
          '/profile',
          headers: {header: 'user-B'},
        );
        expect(first.data, {'hit': 1});
        expect(second.data, {'hit': 2});
        expect(transport.hits, 2);
        expect(storage.values, isEmpty);
      },
    );
  }

  test(
    'sensitive headers cannot read or replace an anonymous cached body',
    () async {
      final client = build();
      await client.get('/profile');
      final stored = Map<String, Object?>.of(storage.values);
      final response = await client.get(
        '/profile',
        headers: {'X-Api-Key': 'A'},
      );
      expect(response.data, {'hit': 2});
      expect(storage.values, stored);
      expect((await client.get('/profile')).data, {'hit': 1});
    },
  );

  for (final vary in <List<String>>[
    ['X-Api-Key'],
    ['Accept-Language'],
    ['*'],
    ['Accept-Encoding, X-Region'],
    ['  ACCEPT  ', 'X-Region'],
  ]) {
    test(
      'Vary $vary is not represented by the URL key and is not stored',
      () async {
        final client = build(vary: vary);
        await client.get('/feed', headers: {'Accept-Language': 'en'});
        final second = await client.get(
          '/feed',
          headers: {'Accept-Language': 'vi'},
        );
        expect(second.data, {'hit': 2});
        expect(transport.hits, 2);
        expect(
          storage.values.keys.where((key) => key.startsWith('http_cache_')),
          isEmpty,
        );
      },
    );
  }

  test('anonymous GETs without Vary still reuse the cached body', () async {
    final client = build();
    expect((await client.get('/feed')).data, {'hit': 1});
    expect((await client.get('/feed')).data, {'hit': 1});
    expect(transport.hits, 1);
  });

  test('upgrade purges bodies admitted by the former header policy', () async {
    seedPreviousPolicy();
    final client = build();
    final response = await client.get('/profile');
    expect(response.data, {'hit': 1});
    expect(transport.hits, 1);
    expect(storage.values.values.join(), isNot(contains('old-user')));
  });

  for (final hasSibling in [false, true]) {
    test(
      'an unindexed legacy body is not replayed (sibling: $hasSibling)',
      () async {
        final oldKey = seedPreviousPolicy();
        storage.values.remove('http_cache_index');
        if (hasSibling) {
          final sibling = CacheInterceptor.cacheKeyFor(
            RequestOptions(
              path: '/other',
              baseUrl: AppConfig.baseUrl + ApiEndpoints.apiVersion,
            ),
          );
          storage.values
            ..['http_cache_index'] = [sibling]
            ..[sibling] = '"old-public-body"'
            ..['http_cache_timestamp_$sibling'] = DateTime.now()
                .toUtc()
                .toIso8601String();
        }
        final client = build();
        expect((await client.get('/profile')).data, {'hit': 1});
        expect(transport.hits, 1);
        expect(storage.values[oldKey], isNot(contains('old-user')));
      },
    );
  }

  test(
    'a refused upgrade purge cannot replay old data and retries later',
    () async {
      final refusing = _RejectDeletionStorage();
      storage = refusing;
      final oldKey = seedPreviousPolicy();
      final client = build();
      expect((await client.get('/profile')).data, {'hit': 1});
      expect(storage.values[oldKey], contains('old-user'));
      expect(storage.values['cache_rule_version'], 2);
      refusing.reject = false;
      expect((await client.get('/profile')).data, {'hit': 2});
      expect((await client.get('/profile')).data, {'hit': 2});
      expect(transport.hits, 2);
      expect(storage.values.values.join(), isNot(contains('old-user')));
    },
  );

  test(
    'a refused replacement write cannot admit an orphaned private body',
    () async {
      storage = _RejectBodyWriteStorage();
      final key = seedPreviousPolicy();
      storage.values.remove('http_cache_index');
      final client = build();
      expect((await client.get('/profile')).data, {'hit': 1});
      expect((await client.get('/profile')).data, {'hit': 2});
      expect(transport.hits, 2);
      expect(storage.values[key], contains('old-user'));
      expect(storage.values['http_cache_index'], isNull);
      expect(storage.values['cache_rule_version'], 2);
    },
  );

  test('a Vary response evicts a previously cached body at its URL', () async {
    final vary = <String>[];
    final client = build(vary: vary);
    await client.get('/feed');
    vary.add('Accept-Language');
    expect(
      (await client.get('/feed', headers: {'cache-control': 'no-cache'})).data,
      {'hit': 2},
    );
    expect(
      storage.values.keys.where((key) => key.startsWith('http_cache_')),
      isEmpty,
    );
    expect((await client.get('/feed')).data, {'hit': 3});
  });
}
