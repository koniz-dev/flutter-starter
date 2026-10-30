// A GET whose query carried a secret - an email-verification or reset token,
// a one-time code, a presigned URL's signature - had its response body stored
// in plaintext shared_preferences whenever the server sent no Cache-Control.
// Hashing the key kept the token out of the key, not out of the stored body.
// Such a request now bypasses the cache, by the same key rule the logging
// interceptor redacts with.

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/network/interceptors/api_logging_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/cache_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/in_memory_stores.dart';

class _ResponseHandler extends ResponseInterceptorHandler {}

class _RequestHandler extends RequestInterceptorHandler {
  Response<dynamic>? resolved;

  @override
  void resolve(
    Response<dynamic> response, [
    bool callFollowingResponseInterceptor = true,
  ]) => resolved = response;
}

RequestOptions _get(Map<String, dynamic> query) => RequestOptions(
  path: '/auth/verify',
  method: 'GET',
  baseUrl: 'https://api.example.com',
  queryParameters: query,
);

void main() {
  late InMemoryStorage storage;
  late CacheInterceptor interceptor;

  Iterable<String> cacheKeys() =>
      storage.values.keys.where((k) => k.startsWith('http_cache_'));

  Future<void> respond(RequestOptions options) => interceptor.onResponse(
    Response<dynamic>(requestOptions: options, statusCode: 200, data: 'body'),
    _ResponseHandler(),
  );

  setUp(() {
    storage = InMemoryStorage();
    interceptor = CacheInterceptor(storageService: storage);
  });

  for (final key in ['token', 'access_token', 'X-Amz-Signature', 'otp']) {
    test('?$key=... is neither written nor served from the cache', () async {
      final options = _get({key: 's3cr3t'});
      await respond(options);
      expect(cacheKeys(), isEmpty, reason: 'nothing written');

      // Even an entry already stored under its key is not served.
      final stored = CacheInterceptor.cacheKeyFor(options);
      storage.values[stored] = '"old"';
      storage.values['http_cache_timestamp_$stored'] = DateTime.now()
          .toUtc()
          .toIso8601String();
      final handler = _RequestHandler();
      await interceptor.onRequest(options, handler);
      expect(handler.resolved, isNull, reason: 'not served from the cache');
    });
  }

  test('a non-sensitive query is still cached', () async {
    await respond(_get({'page': '2'}));

    expect(cacheKeys(), isNotEmpty);
  });

  test('the cache uses the logging redaction rule, not a copy', () async {
    const keys = [
      'token',
      'refresh_token',
      'api_key',
      'X-Amz-Signature',
      'otp',
      'password',
      'page',
      'sort',
      'q',
    ];
    for (final key in keys) {
      storage.values.clear();
      await respond(_get({key: 'v'}));
      expect(
        cacheKeys().isEmpty,
        ApiLoggingInterceptor.isSensitiveKey(key),
        reason: key,
      );
    }
  });
}
