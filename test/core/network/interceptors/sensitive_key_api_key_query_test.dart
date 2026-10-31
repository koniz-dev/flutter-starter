// A Google APIs key travels as `?key=AIza...`, and `key` was not in the
// sensitive-key rule, so such a GET had the key logged in clear and its body
// cached in plaintext. `key` is an exact-match entry: `monkey` and `keyword`
// are left alone, and a literal `key` query parameter now skips the cache.

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/network/interceptors/api_logging_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/cache_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/in_memory_stores.dart';

class _ResponseHandler extends ResponseInterceptorHandler {}

void main() {
  test('a Google APIs GET is neither cached nor logged with its key', () async {
    final storage = InMemoryStorage();
    const key = 'AIzaSyEXAMPLEKEY000000000000000000000';
    final options = RequestOptions(
      path: '/maps/api/geocode/json',
      method: 'GET',
      baseUrl: 'https://maps.googleapis.com',
      queryParameters: {'address': 'Hanoi', 'key': key},
    );

    await CacheInterceptor(storageService: storage).onResponse(
      Response<dynamic>(requestOptions: options, statusCode: 200, data: '{}'),
      _ResponseHandler(),
    );

    expect(
      storage.values.keys.where((k) => k.startsWith('http_cache_')),
      isEmpty,
      reason: 'no body, timestamp or index entry',
    );
    final logged = ApiLoggingInterceptor.redactPath(
      '/maps/api/geocode/json?address=Hanoi&key=$key',
    );
    expect(logged, isNot(contains(key)));
    expect(logged, contains('address=Hanoi'));
  });

  test('a GET whose query keys only resemble key is still cached', () async {
    final storage = InMemoryStorage();
    final options = RequestOptions(
      path: '/search',
      method: 'GET',
      baseUrl: 'https://api.example.com',
      queryParameters: {'keyword': 'monkey', 'monkey': '1'},
    );

    await CacheInterceptor(storageService: storage).onResponse(
      Response<dynamic>(requestOptions: options, statusCode: 200, data: '{}'),
      _ResponseHandler(),
    );

    expect(
      storage.values.keys.where((k) => k.startsWith('http_cache_')),
      isNotEmpty,
    );
  });
}
