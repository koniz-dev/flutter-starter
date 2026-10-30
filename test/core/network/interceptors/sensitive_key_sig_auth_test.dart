// `sig` (an Azure Storage SAS signature) and `auth` (a Firebase Realtime
// Database REST ID token) were not in the sensitive-key rule, so an anonymous
// GET carrying either had the secret logged in clear and its body cached in
// plaintext. They are exact-match entries, so `signal` and `author` are left
// alone.

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/network/interceptors/api_logging_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/cache_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/in_memory_stores.dart';

class _ResponseHandler extends ResponseInterceptorHandler {}

void main() {
  test('sig and auth are secrets; signal and author are not', () {
    expect(ApiLoggingInterceptor.isSensitiveKey('sig'), isTrue);
    expect(ApiLoggingInterceptor.isSensitiveKey('auth'), isTrue);
    expect(ApiLoggingInterceptor.isSensitiveKey('signal'), isFalse);
    expect(ApiLoggingInterceptor.isSensitiveKey('author'), isFalse);
    expect(ApiLoggingInterceptor.isSensitiveKey('oauth_provider'), isFalse);
  });

  test('an Azure SAS GET is neither cached nor logged with its sig', () async {
    final storage = InMemoryStorage();
    final options = RequestOptions(
      path: '/container/blob.png',
      method: 'GET',
      baseUrl: 'https://account.blob.core.windows.net',
      queryParameters: {'sv': '2022-11-02', 'sr': 'b', 'sig': 'S3CR3TSIG'},
    );

    await CacheInterceptor(storageService: storage).onResponse(
      Response<dynamic>(requestOptions: options, statusCode: 200, data: 'png'),
      _ResponseHandler(),
    );

    expect(
      storage.values.keys.where((k) => k.startsWith('http_cache_')),
      isEmpty,
      reason: 'no body, timestamp or index entry',
    );
    final logged = ApiLoggingInterceptor.redactPath(
      '/container/blob.png?sv=2022-11-02&sr=b&sig=S3CR3TSIG',
    );
    expect(logged, isNot(contains('S3CR3TSIG')));
    expect(logged, contains('sv=2022-11-02'));
  });
}
