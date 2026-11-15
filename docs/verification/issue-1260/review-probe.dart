import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_starter/core/network/interceptors/cache_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../test/helpers/in_memory_stores.dart';

class _Adapter implements HttpClientAdapter {
  int hits = 0;
  List<String> vary = [];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream, Future<void>? cancel) async {
    return ResponseBody.fromString(jsonEncode({'network': ++hits}), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      if (vary.isNotEmpty) 'vary': vary,
    });
  }
  @override
  void close({bool force = false}) {}
}

class _RejectBodyWrite extends InMemoryStorage {
  @override
  Future<bool> setString(String key, String value) async {
    if (key.startsWith('http_cache_') && !key.startsWith('http_cache_timestamp_')) return false;
    return await super.setString(key, value);
  }
}

void main() {
  test('a refused replacement write cannot certify a legacy private body', () async {
    final storage = _RejectBodyWrite();
    final key = CacheInterceptor.cacheKeyFor(RequestOptions(path: '/profile', baseUrl: 'https://api.review.invalid'));
    storage.values
      ..[key] = jsonEncode({'owner': 'previous-private-session'})
      ..['http_cache_timestamp_$key'] = DateTime.now().toUtc().toIso8601String()
      ..['cache_rule_version'] = 2;
    final adapter = _Adapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.review.invalid'))
      ..interceptors.add(CacheInterceptor(storageService: storage))
      ..httpClientAdapter = adapter;
    expect((await dio.get<dynamic>('/profile')).data, {'network': 1});
    expect((await dio.get<dynamic>('/profile')).data, {'network': 2});
    expect(adapter.hits, 2);
  });

  for (final indexedSibling in [false, true]) {
    test('legacy unindexed hashed body is not replayed (indexed sibling $indexedSibling)', () async {
      final storage = InMemoryStorage();
      final key = CacheInterceptor.cacheKeyFor(RequestOptions(path: '/profile', baseUrl: 'https://api.review.invalid'));
      final sibling = CacheInterceptor.cacheKeyFor(RequestOptions(path: '/catalog', baseUrl: 'https://api.review.invalid'));
      storage.values
        ..[key] = jsonEncode({'owner': 'previous-private-session'})
        ..['http_cache_timestamp_$key'] = DateTime.now().toUtc().toIso8601String()
        ..['cache_rule_version'] = 2;
      if (indexedSibling) {
        storage.values
          ..[sibling] = '{}'
          ..['http_cache_timestamp_$sibling'] = DateTime.now().toUtc().toIso8601String()
          ..['http_cache_index'] = [sibling];
      }
      final adapter = _Adapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.review.invalid'))
        ..interceptors.add(CacheInterceptor(storageService: storage))
        ..httpClientAdapter = adapter;
      final response = await dio.get<dynamic>('/profile');
      expect(response.data, {'network': 1});
      expect(adapter.hits, 1);
    });
  }

  for (final header in ['x-aPi-kEy', 'x-auth_token', 'X-Custom-Secret']) {
    test('mixed-case/nonstandard credential header $header bypasses read/write', () async {
      final storage = InMemoryStorage();
      final adapter = _Adapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.review.invalid'))
        ..interceptors.add(CacheInterceptor(storageService: storage))
        ..httpClientAdapter = adapter;
      await dio.get<dynamic>('/profile', options: Options(headers: {header: 'A'}));
      final response = await dio.get<dynamic>('/profile', options: Options(headers: {header: 'B'}));
      expect(response.data, {'network': 2});
      expect(storage.values, isEmpty);
    });
  }

  test('Vary multi-line response is not cached', () async {
    final storage = InMemoryStorage();
    final adapter = _Adapter()..vary = ['Accept-Language', ' Accept-Encoding, *'];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.review.invalid'))
      ..interceptors.add(CacheInterceptor(storageService: storage))
      ..httpClientAdapter = adapter;
    await dio.get<dynamic>('/public');
    expect((await dio.get<dynamic>('/public')).data, {'network': 2});
    expect(storage.values.keys.where((key) => key.startsWith('http_cache_')), isEmpty);
  });

  test('anonymous control reuses public body', () async {
    final storage = InMemoryStorage();
    final adapter = _Adapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.review.invalid'))
      ..interceptors.add(CacheInterceptor(storageService: storage))
      ..httpClientAdapter = adapter;
    await dio.get<dynamic>('/public');
    expect((await dio.get<dynamic>('/public')).data, {'network': 1});
    expect(adapter.hits, 1);
  });
}
