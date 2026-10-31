// A GET whose query names a secret neither reads from nor writes to the
// cache, and the set of secret names grows. A response an earlier build
// cached for such a URL sat under a hashed key that nothing read or evicted
// again, in plaintext storage. The cache now records the key-rule version it
// was written under, and drops every entry when the version changes. A purge
// that failed used to be remembered as done; it is now retried.

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/network/interceptors/api_logging_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/cache_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/in_memory_stores.dart';

class _RequestHandler extends RequestInterceptorHandler {}

RequestOptions _get(String path) => RequestOptions(
  path: path,
  method: 'GET',
  baseUrl: 'https://api.example.com',
);

/// Fails its first read of the cache index, then behaves.
class _FlakyIndexStorage extends InMemoryStorage {
  var _failed = false;

  @override
  Future<List<String>?> getStringList(String key) async {
    if (key == 'http_cache_index' && !_failed) {
      _failed = true;
      throw Exception('storage busy');
    }
    return await super.getStringList(key);
  }
}

void main() {
  test('the key rules match their version', () {
    // Changed the sensitive-key sets in ApiLoggingInterceptor? Bump
    // sensitiveKeyRuleVersion and update both values here: the cache then
    // drops the responses an earlier rule let it store.
    expect(ApiLoggingInterceptor.sensitiveKeyRuleVersion, 1);
    expect(
      ApiLoggingInterceptor.debugKeyRuleFingerprint,
      'accesskey,apikey,appkey,authkey,authorization,cardnumber,clientkey,'
      'credential,creditcard,functionskey,hmac,jwt,licensekey,masterkey,'
      'otpcode,passphrase,passwd,password,pincode,privatekey,secret,'
      'sessionkey,signature,subscriptionkey,token'
      '|access,auth,bearer,cvc,cvv,key,otp,pin,refresh,session,sessionid,sig,'
      'sign'
      '|code',
    );
  });

  test(
    'entries cached under an older rule are dropped on the first request',
    () async {
      final storage = InMemoryStorage();
      // Cached for `?key=AIza...` before `key` was a secret.
      final stale = CacheInterceptor.cacheKeyFor(_get('/maps?key=AIza'));
      storage.values
        ..[stale] = '{"place":"x"}'
        ..['http_cache_timestamp_$stale'] = '2026-10-30T00:00:00.000Z'
        ..['cache_rule_version'] =
            ApiLoggingInterceptor.sensitiveKeyRuleVersion - 1;
      await storage.setStringList('http_cache_index', [stale]);

      await CacheInterceptor(
        storageService: storage,
      ).onRequest(_get('/anything'), _RequestHandler());

      expect(storage.values.containsKey(stale), isFalse);
      expect(
        storage.values.containsKey('http_cache_timestamp_$stale'),
        isFalse,
      );
      expect(await storage.getStringList('http_cache_index'), isNull);
    },
  );

  test('entries with no recorded rule are dropped too', () async {
    final storage = InMemoryStorage();
    final stale = CacheInterceptor.cacheKeyFor(_get('/catalog'));
    storage.values[stale] = '{"ok":true}';
    await storage.setStringList('http_cache_index', [stale]);

    await CacheInterceptor(
      storageService: storage,
    ).onRequest(_get('/anything'), _RequestHandler());

    expect(storage.values.containsKey(stale), isFalse);
  });

  test('a purge that fails runs again on the next request', () async {
    final storage = _FlakyIndexStorage();
    const legacy = 'http_cache_https://api.example.com/verify?token=old';
    storage.values[legacy] = '{"ok":true}';
    await storage.setStringList('http_cache_index', [legacy]);
    final interceptor = CacheInterceptor(storageService: storage);

    await interceptor.onRequest(_get('/a'), _RequestHandler());
    expect(storage.values.containsKey(legacy), isTrue, reason: 'it failed');

    await interceptor.onRequest(_get('/b'), _RequestHandler());
    expect(storage.values.containsKey(legacy), isFalse);
  });
}
