import 'package:dio/dio.dart';
import '1192-baseline-api.dart';
import '1192-baseline-cache.dart';
import 'package:flutter_test/flutter_test.dart';

import '1192-baseline-stores.dart';

class _RequestHandler extends RequestInterceptorHandler {
  bool resolved = false;

  @override
  void resolve(
    Response<dynamic> response, [
    bool callFollowingResponseInterceptor = false,
  ]) {
    resolved = true;
    super.resolve(response, callFollowingResponseInterceptor);
  }
}

class _ResponseHandler extends ResponseInterceptorHandler {}

void main() {
  const redacted = '***REDACTED***';
  const cases = {
    'https://app.example/cb#access_token=SECRET&state=ok':
        'https://app.example/cb#access_token=$redacted&state=ok',
    '/cb#id_token=SECRET&state=ok': '/cb#id_token=$redacted&state=ok',
    '/cb?token=QUERY_SECRET#access_token=FRAGMENT_SECRET&state=ok':
        '/cb?token=$redacted#access_token=$redacted&state=ok',
    '/cb#access%5Ftoken=SECRET&state=ok':
        '/cb#access%5Ftoken=$redacted&state=ok',
    '/cb#bad%=SECRET&state=ok': '/cb#bad%=$redacted&state=ok',
    '/cb#access_token=SECRET?still_secret&state=ok':
        '/cb#access_token=$redacted&state=ok',
    '/cb#/route?code=SECRET&state=ok': '/cb#/route?code=$redacted&state=ok',
    '/cb#token?public=SECRET&state=ok': '/cb#token?public=$redacted&state=ok',
    '/cb#access?token=SECRET&state=ok': '/cb#access?token=$redacted&state=ok',
    '/cb#!/route?code=SECRET&state=ok': '/cb#!/route?code=$redacted&state=ok',
    '/cb#ticket=SECRET&state=ok': '/cb#ticket=$redacted&state=ok',
    'ws://app.example/socket?TiCkEt=SECRET&state=ok':
        'ws://app.example/socket?TiCkEt=$redacted&state=ok',
    '/socket?tic%6Bet=SECRET&state=ok': '/socket?tic%6Bet=$redacted&state=ok',
  };
  for (final entry in cases.entries) {
    test('redacts credential parameters in ${entry.key}', () {
      expect(ApiLoggingInterceptor.redactUrl(entry.key), entry.value);
      expect(ApiLoggingInterceptor.redactPath(entry.key), entry.value);
    });
  }

  test('ordinary fragments and unrelated fields remain readable', () {
    for (final path in [
      '/guide#section-2',
      '/guide#section?view=compact',
      '/guide#/token/callback?view=compact',
      '/guide?view=compact#section-2',
      '/socket?ticketCount=2&tickets=public#section',
    ]) {
      expect(ApiLoggingInterceptor.redactUrl(path), path);
    }
    expect(ApiLoggingInterceptor.isSensitiveQueryKey('ticket'), isTrue);
    expect(ApiLoggingInterceptor.isSensitiveKey('ticket'), isFalse);
  });

  test(
    'ticket-authenticated responses bypass cache and purge older rules',
    () async {
      final options = RequestOptions(
        path: '/socket?ticket=TICKET_SECRET',
        baseUrl: 'https://app.example',
        method: 'GET',
      );
      final key = CacheInterceptor.cacheKeyFor(options);
      final storage = InMemoryStorage();
      storage.values
        ..['cache_rule_version'] = 1
        ..[key] = '{"private":"old response"}'
        ..['http_cache_timestamp_$key'] = DateTime.now().toIso8601String();
      await storage.setStringList('http_cache_index', [key]);
      final interceptor = CacheInterceptor(storageService: storage);
      final handler = _RequestHandler();
      await interceptor.onRequest(options, handler);
      expect(
        handler.resolved,
        isFalse,
        reason: 'never replay old ticket response',
      );
      await interceptor.onResponse(
        Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: 'private',
        ),
        _ResponseHandler(),
      );
      expect(
        storage.values.keys.where((key) => key.startsWith('http_cache_')),
        isEmpty,
      );
      expect(storage.values['cache_rule_version'], 2);
    },
  );
}
