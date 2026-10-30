// CacheInterceptor wrote every anonymous 200 GET to plaintext storage. It
// read only the request's Cache-Control, never the response's, so a body the
// server marked no-store or private was kept anyway; and the key was the full
// URL, so a token in the query sat on disk in the key and in the key index.
// An anonymous user never logs out, so nothing ever cleared it.

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/network/interceptors/cache_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/in_memory_stores.dart';

class _ResponseHandler extends ResponseInterceptorHandler {}

class _RequestHandler extends RequestInterceptorHandler {}

RequestOptions _get(String path, [Map<String, dynamic>? query]) =>
    RequestOptions(
      path: path,
      method: 'GET',
      baseUrl: 'https://api.example.com',
      queryParameters: query,
    );

Response<dynamic> _ok(
  RequestOptions options, [
  Map<String, List<String>> headers = const {},
]) => Response<dynamic>(
  requestOptions: options,
  statusCode: 200,
  data: {'ok': true},
  headers: Headers.fromMap(headers),
);

void main() {
  late InMemoryStorage storage;
  late CacheInterceptor interceptor;

  Iterable<String> cacheKeys() =>
      storage.values.keys.where((k) => k.startsWith('http_cache_'));

  setUp(() {
    storage = InMemoryStorage();
    interceptor = CacheInterceptor(storageService: storage);
  });

  group('a response the server marks as not for this cache is not stored', () {
    final refusals = <String, Map<String, List<String>>>{
      'Cache-Control: no-store': {
        'cache-control': ['no-store'],
      },
      'Cache-Control: private': {
        'cache-control': ['private'],
      },
      'Cache-Control: max-age=60, Private': {
        'cache-control': ['max-age=60, Private'],
      },
      'Cache-Control: private="set-cookie"': {
        'cache-control': ['private="set-cookie"'],
      },
      'Set-Cookie': {
        'set-cookie': ['session=abc; HttpOnly'],
      },
    };

    for (final MapEntry(key: label, value: headers) in refusals.entries) {
      test(label, () async {
        await interceptor.onResponse(
          _ok(_get('/auth/verify-email'), headers),
          _ResponseHandler(),
        );

        expect(cacheKeys(), isEmpty);
      });
    }

    test('while a response with no such directive is stored', () async {
      await interceptor.onResponse(
        _ok(_get('/catalog'), {
          'cache-control': ['public, max-age=60'],
        }),
        _ResponseHandler(),
      );

      expect(cacheKeys(), isNotEmpty);
    });
  });

  test(
    'a token in the query is in no stored key and not in the index',
    () async {
      await interceptor.onResponse(
        _ok(_get('/auth/verify-email', {'token': 's3cr3t-token'})),
        _ResponseHandler(),
      );

      expect(cacheKeys(), isNotEmpty, reason: 'the response was cached');
      for (final key in storage.values.keys) {
        expect(key, isNot(contains('s3cr3t-token')));
      }
      final index = await storage.getStringList('http_cache_index');
      expect(index, isNotNull);
      expect(index!.join(), isNot(contains('s3cr3t-token')));
    },
  );

  test('entries stored under a verbatim URL key are removed on first use, '
      'and the hashed ones kept', () async {
    const legacy =
        'http_cache_https://api.example.com/auth/verify-email?token=old_{}';
    final current = CacheInterceptor.cacheKeyFor(_get('/catalog'));
    storage.values
      ..[legacy] = '{"ok":true}'
      ..['http_cache_timestamp_$legacy'] = '2026-10-30T00:00:00.000Z'
      ..[current] = '{"ok":true}'
      ..['http_cache_timestamp_$current'] = '2026-10-30T00:00:00.000Z';
    await storage.setStringList('http_cache_index', [legacy, current]);

    await interceptor.onRequest(_get('/anything'), _RequestHandler());

    expect(storage.values.containsKey(legacy), isFalse);
    expect(storage.values.containsKey('http_cache_timestamp_$legacy'), isFalse);
    expect(storage.values.containsKey(current), isTrue);
    expect(await storage.getStringList('http_cache_index'), [current]);
  });
}
