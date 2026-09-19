// Drives the fully assembled ApiClient through a fake HttpClientAdapter and a
// real in-memory StorageService to prove the HTTP response cache never stores
// an authenticated response, never crosses identities, and is emptied by the
// logout path.
//
// Regression cover for koniz-dev/flutter-starter#77. Before the fix,
// CacheInterceptor decided whether to bypass the cache by looking for an
// `Authorization` header on the outgoing RequestOptions. It sits at index 1
// and AuthInterceptor at index 2, and dio runs onRequest in registration
// order, so on the request leg the header it looked for did not exist yet.
// clearCache() had an empty body and no callers.
//
// Counterfactual, actually run (docs/verification/issue-77/counterfactual.log):
// with `_hasSessionCredential()` replaced by `return false` (header sniff only)
// and `clearCache()` restored to an empty body, 4 of these 9 tests fail:
//
//   - 'the interceptor bypasses the cache ... when the token store holds a
//     credential' - the headerless RequestOptions CacheInterceptor sees at
//     index 1 gets its body written to storage.
//   - 'an anonymously cached body is not replayed to an authenticated request'
//     - the authenticated GET is served the previous anonymous body.
//   - both 'logout empties the HTTP response cache' cases - nothing is removed.
//
// Worth being precise about what pre-fix behaviour actually was, because the
// filed issue overstates one half. dio runs onResponse in registration order
// too (dio-5.9.2/lib/src/dio_mixin.dart:495-500) and `response.requestOptions`
// is the *same* RequestOptions instance AuthInterceptor mutated, so by the time
// the old header sniff ran on the response leg the `Authorization` header WAS
// present and the write was skipped. The dead check therefore bit on the
// request leg only: authenticated GETs were not written to shared_preferences
// through this assembly, but they were happily *served* from an entry cached
// earlier in an anonymous session, and nothing ever cleared it.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/api_logging_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/cache_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/error_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/retry_interceptor.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';
import 'package:flutter_starter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorageService extends Mock implements SecureStorageService {}

/// A real in-memory StorageService, so the tests assert on what was actually
/// persisted rather than on which mock methods happened to be called.
class _InMemoryStorage implements StorageService {
  final Map<String, Object?> values = {};

  /// Every key holding a cached response body (not its timestamp or index).
  List<String> get cachedBodyKeys => values.keys
      .where(
        (k) =>
            k.startsWith('http_cache_') &&
            !k.startsWith('http_cache_timestamp_') &&
            k != 'http_cache_index',
      )
      .toList();

  @override
  Future<void> init() async {}

  @override
  Future<bool> clear() async {
    values.clear();
    return true;
  }

  @override
  Future<bool> containsKey(String key) async => values.containsKey(key);

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }

  @override
  Future<String?> getString(String key) async => values[key] as String?;

  @override
  Future<bool> setString(String key, String value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<int?> getInt(String key) async => values[key] as int?;

  @override
  Future<bool> setInt(String key, int value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;

  @override
  Future<bool> setBool(String key, {required bool value}) async {
    values[key] = value;
    return true;
  }

  @override
  Future<double?> getDouble(String key) async => values[key] as double?;

  @override
  Future<bool> setDouble(String key, double value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<List<String>?> getStringList(String key) async =>
      values[key] as List<String>?;

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    values[key] = value;
    return true;
  }
}

class _InMemoryTokenStore implements ITokenStore {
  String? accessToken;
  String? refreshToken;

  @override
  Future<void> clearAccessToken() async => accessToken = null;

  @override
  Future<void> clearAllTokens() async {
    accessToken = null;
    refreshToken = null;
  }

  @override
  Future<void> clearRefreshToken() async => refreshToken = null;

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<bool> setAccessToken(String token) async {
    accessToken = token;
    return true;
  }

  @override
  Future<bool> setRefreshToken(String token) async {
    refreshToken = token;
    return true;
  }
}

/// Adapter that counts every fetch and replies from a scripted queue.
///
/// The last scripted reply repeats once the queue is exhausted.
class _CountingAdapter implements HttpClientAdapter {
  _CountingAdapter(this._replies);

  final List<Map<String, dynamic>> _replies;

  int hits = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final index = hits < _replies.length ? hits : _replies.length - 1;
    hits++;
    return ResponseBody.fromString(
      jsonEncode(_replies[index]),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Minimal remote data source: logout succeeds, nothing else is exercised.
class _StubRemoteDataSource implements AuthRemoteDataSource {
  int logoutCalls = 0;

  @override
  Future<void> logout() async => logoutCalls++;

  @override
  Future<AuthResponseModel> login(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<AuthResponseModel> register(
    String email,
    String password,
    String name,
  ) => throw UnimplementedError();

  @override
  Future<AuthResponseModel> refreshToken(String refreshToken) =>
      throw UnimplementedError();
}

/// Minimal local data source backed by the shared token store.
class _StubLocalDataSource implements AuthLocalDataSource {
  _StubLocalDataSource(this._tokenStore);

  final _InMemoryTokenStore _tokenStore;

  @override
  Future<void> clearCache() async => _tokenStore.clearAllTokens();

  @override
  Future<void> cacheRefreshToken(String token) async =>
      _tokenStore.setRefreshToken(token);

  @override
  Future<void> cacheToken(String token) async =>
      _tokenStore.setAccessToken(token);

  @override
  Future<void> cacheUser(UserModel user) async {}

  @override
  Future<UserModel?> getCachedUser() async => null;

  @override
  Future<String?> getRefreshToken() => _tokenStore.getRefreshToken();

  @override
  Future<String?> getToken() => _tokenStore.getAccessToken();
}

void main() {
  late _InMemoryStorage storage;
  late _InMemoryTokenStore tokenStore;
  late _MockSecureStorageService secureStorage;

  setUp(() {
    storage = _InMemoryStorage();
    tokenStore = _InMemoryTokenStore();
    secureStorage = _MockSecureStorageService();
  });

  ApiClient buildClient(_CountingAdapter adapter) {
    return ApiClient(
      storageService: storage,
      secureStorageService: secureStorage,
      authInterceptor: AuthInterceptor(
        tokenStore: tokenStore,
        refreshToken: () async => const Success('unused'),
      ),
    )..dio.httpClientAdapter = adapter;
  }

  group('HTTP cache never stores an authenticated response (#77)', () {
    test('an authenticated GET is never written to storage', () async {
      tokenStore.accessToken = 'user-a-access-token';
      final adapter = _CountingAdapter([
        {'email': 'a@example.com', 'ssn': '000-00-0000'},
      ]);
      final apiClient = buildClient(adapter);

      final response = await apiClient.get('/users/me');

      expect(response.statusCode, 200);
      expect(adapter.hits, 1);
      // Criterion 1: nothing at all reached shared_preferences.
      expect(
        storage.values,
        isEmpty,
        reason: 'an authenticated response body must never be persisted',
      );
    });

    test(
      'a repeat authenticated GET always goes to the network, never to cache',
      () async {
        tokenStore.accessToken = 'user-a-access-token';
        final adapter = _CountingAdapter([
          {'balance': 1},
          {'balance': 2},
        ]);
        final apiClient = buildClient(adapter);

        final first = await apiClient.get('/account');
        final second = await apiClient.get('/account');

        expect(adapter.hits, 2);
        expect(first.data, {'balance': 1});
        expect(second.data, {'balance': 2});
      },
    );

    test(
      'an anonymous GET is still cached, which proves the assertions above '
      'would catch a regression rather than passing vacuously',
      () async {
        final adapter = _CountingAdapter([
          {'motd': 'hello'},
        ]);
        final apiClient = buildClient(adapter);

        await apiClient.get('/public/config');
        final second = await apiClient.get('/public/config');

        // Served from cache: the transport was hit once.
        expect(adapter.hits, 1);
        expect(second.data, {'motd': 'hello'});
        expect(storage.cachedBodyKeys, hasLength(1));
      },
    );
  });

  group('cache guard does not depend on interceptor order (#77)', () {
    test(
      'CacheInterceptor still precedes AuthInterceptor, so the guard must '
      'not be header-derived',
      () async {
        tokenStore.accessToken = 'user-a-access-token';
        final adapter = _CountingAdapter([
          {'secret': 'a'},
        ]);
        final apiClient = buildClient(adapter);

        // dio installs its own (unexported) ImplyContentTypeInterceptor at
        // index 0; assert on the interceptors ApiClient registers.
        final types = apiClient.dio.interceptors
            .map((i) => i.runtimeType)
            .where((t) => '$t' != 'ImplyContentTypeInterceptor')
            .toList();

        // The registered order is unchanged from #46: ErrorInterceptor last.
        expect(types, [
          CacheInterceptor,
          AuthInterceptor,
          RetryInterceptor,
          ErrorInterceptor,
        ]);
        expect(types.last, ErrorInterceptor);
        expect(types.indexOf(ApiLoggingInterceptor), -1);

        // CacheInterceptor runs BEFORE the Authorization header is written...
        expect(
          types.indexOf(CacheInterceptor),
          lessThan(types.indexOf(AuthInterceptor)),
        );

        await apiClient.get('/users/me');

        // ...and the authenticated response is still not cached, which is only
        // possible because the bypass decision reads the token store rather
        // than options.headers.
        expect(storage.values, isEmpty);
      },
    );

    test(
      'the interceptor bypasses the cache for a request with no Authorization '
      'header at all when the token store holds a credential',
      () async {
        tokenStore.accessToken = 'user-a-access-token';
        final interceptor = CacheInterceptor(
          storageService: storage,
          tokenStore: tokenStore,
        );
        // Headers deliberately empty: this is exactly what CacheInterceptor
        // sees at index 1, before AuthInterceptor has run.
        final options = RequestOptions(path: '/users/me', method: 'GET');
        expect(options.headers.containsKey('authorization'), isFalse);

        await interceptor.onResponse(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: {'secret': 'a'},
          ),
          ResponseInterceptorHandler(),
        );

        expect(storage.values, isEmpty);
      },
    );
  });

  group('cache never crosses identities (#77)', () {
    test(
      "a second identity never sees the first identity's cached body",
      () async {
        final adapter = _CountingAdapter([
          {'name': 'user-a'},
          {'name': 'user-b'},
        ]);
        final apiClient = buildClient(adapter);

        tokenStore.accessToken = 'token-a';
        final firstBody = await apiClient.get('/profile');

        tokenStore.accessToken = 'token-b';
        final secondBody = await apiClient.get('/profile');

        expect(firstBody.data, {'name': 'user-a'});
        // Criterion 3: user B got their own body from the network.
        expect(secondBody.data, {'name': 'user-b'});
        expect(secondBody.data, isNot(firstBody.data));
        expect(adapter.hits, 2);
      },
    );

    test(
      'an anonymously cached body is not replayed to an authenticated request',
      () async {
        final adapter = _CountingAdapter([
          {'motd': 'anonymous'},
          {'motd': 'authenticated'},
        ]);
        final apiClient = buildClient(adapter);

        await apiClient.get('/public/config');
        expect(storage.cachedBodyKeys, hasLength(1));

        tokenStore.accessToken = 'token-a';
        final authenticated = await apiClient.get('/public/config');

        expect(authenticated.data, {'motd': 'authenticated'});
        expect(adapter.hits, 2);
      },
    );
  });

  group('logout empties the HTTP response cache (#77)', () {
    test(
      'a cached body is dropped by the logout path and the next identical GET '
      'goes to the network',
      () async {
        final adapter = _CountingAdapter([
          {'motd': 'before-logout'},
          {'motd': 'after-logout'},
        ]);
        final apiClient = buildClient(adapter);

        // Cache an entry.
        await apiClient.get('/public/config');
        final cached = await apiClient.get('/public/config');
        expect(adapter.hits, 1, reason: 'second GET must be a cache hit');
        expect(cached.data, {'motd': 'before-logout'});
        expect(storage.cachedBodyKeys, hasLength(1));
        expect(storage.values.containsKey('http_cache_index'), isTrue);

        // Drive the real logout path.
        tokenStore.accessToken = 'token-a';
        final repository = AuthRepositoryImpl(
          remoteDataSource: _StubRemoteDataSource(),
          localDataSource: _StubLocalDataSource(tokenStore),
          httpCache: apiClient.responseCache,
        );
        final result = await repository.logout();
        expect(result.isSuccess, isTrue);

        // Criterion 4: every cache key, timestamp and the index are gone.
        expect(storage.values, isEmpty);

        final afterLogout = await apiClient.get('/public/config');
        expect(adapter.hits, 2);
        expect(afterLogout.data, {'motd': 'after-logout'});
      },
    );

    test(
      'clearCache removes every entry it wrote, including timestamps',
      () async {
        final adapter = _CountingAdapter([
          {'a': 1},
        ]);
        final apiClient = buildClient(adapter);

        await apiClient.get('/public/one');
        await apiClient.get('/public/two');
        expect(storage.cachedBodyKeys, hasLength(2));
        expect(
          storage.values.keys.where(
            (k) => k.startsWith('http_cache_timestamp_'),
          ),
          hasLength(2),
        );

        await apiClient.responseCache.clearCache();

        expect(storage.values, isEmpty);
      },
    );
  });
}
