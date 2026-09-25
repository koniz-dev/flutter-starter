// Forced logout - the 401 path through AuthInterceptor - must leave the same
// device state as explicit AuthRepositoryImpl.logout().
//
// Regression cover for koniz-dev/flutter-starter#114. Before the fix,
// `AuthInterceptor._logoutUser()` cleared the tokens and the cached user blob
// but held no reference to the HTTP response cache, so a session that ended by
// token expiry left cached bodies on the device while a session the user ended
// by tapping "log out" did not. #77 decided (its criterion 4) that a logout
// clears the cache; only one of the two logout paths implemented that decision.
//
// Scope of the leak, stated honestly: #77 also made `CacheInterceptor` refuse
// to store authenticated responses, so what forced logout left behind is
// anonymous-scope entries - which still must not outlive a session boundary,
// and which the sample code here can produce today (see the seeded `/public`
// GET below).
//
// Counterfactual, actually run (docs/verification/issue-114/counterfactual.log):
// with `attachResponseCache` never called from `ApiClient._createDio` - i.e.
// pre-fix wiring, the interceptor holding no cache - 4 of these 6 tests fail,
// including the equivalence test, which reports the surviving `http_cache_*`
// keys as the difference between the two paths.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/contracts/network_contracts.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
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
///
/// Doubles as the [IKeyValueStore] holding the cached user blob, exactly as
/// the single `StorageService` instance does in production wiring.
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

/// One scripted transport reply.
class _Reply {
  const _Reply(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;
}

/// Adapter that replies from a scripted queue; the last reply repeats.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._replies);

  final List<_Reply> _replies;

  int hits = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final reply = _replies[hits < _replies.length ? hits : _replies.length - 1];
    hits++;
    return ResponseBody.fromString(
      jsonEncode(reply.body),
      reply.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A response cache whose `clearCache()` always fails.
class _FailingResponseCache implements IHttpResponseCache {
  int clearCalls = 0;

  @override
  Future<void> clearCache() async {
    clearCalls++;
    throw StateError('cache backend unavailable');
  }
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

/// The device state a logout is responsible for tearing down.
///
/// Deliberately a plain map so `equals` compares the two logout paths deeply,
/// in one assertion, rather than per-key.
///
/// Cache timestamps are normalised to a placeholder: two worlds seeded
/// microseconds apart write different `DateTime.now()` values, which would
/// make the comparison fail for a reason that has nothing to do with logout.
/// The *key* is still compared, so an entry one path removes and the other
/// keeps is still a difference.
Map<String, Object?> _deviceState(
  _InMemoryStorage storage,
  _InMemoryTokenStore tokens,
) => <String, Object?>{
  'keyValueStore': <String, Object?>{
    for (final entry in storage.values.entries)
      entry.key: entry.key.startsWith('http_cache_timestamp_')
          ? '<write time>'
          : entry.value,
  },
  'accessToken': tokens.accessToken,
  'refreshToken': tokens.refreshToken,
};

/// One fully assembled app-side world: storage, tokens, client, data sources.
class _World {
  _World(this.storage, this.tokens, this.apiClient, this.adapter, this.local);

  final _InMemoryStorage storage;
  final _InMemoryTokenStore tokens;
  final ApiClient apiClient;
  final _ScriptedAdapter adapter;
  final AuthLocalDataSource local;

  Map<String, Object?> get state => _deviceState(storage, tokens);
}

/// Refresh outcome standing in for "there is no usable refresh token": exactly
/// what `AuthRepositoryImpl.refreshToken()` returns when the store is empty.
const _refreshUnavailable = ResultFailure<String>(
  UnknownFailure('No refresh token available'),
);

void main() {
  /// Builds a world, caches one anonymous response body, then signs a user in.
  ///
  /// Every test starts from this same seeded state so the two logout paths are
  /// compared from an identical device.
  Future<_World> seedSignedInWorld({
    Future<Result<String>> Function()? refreshToken,
    List<_Reply>? replies,
  }) async {
    final storage = _InMemoryStorage();
    final tokens = _InMemoryTokenStore();
    final adapter = _ScriptedAdapter(
      replies ??
          const [
            _Reply(200, {'motd': 'cached-before-logout'}),
            _Reply(401, {'error': 'token expired'}),
          ],
    );
    final apiClient = ApiClient(
      storageService: storage,
      secureStorageService: _MockSecureStorageService(),
      authInterceptor: AuthInterceptor(
        tokenStore: tokens,
        refreshToken: refreshToken ?? () async => _refreshUnavailable,
        // Wired exactly as `authInterceptorProvider` wires it, so the
        // cached user blob is part of the state under comparison.
        keyValueStore: storage,
      ),
    )..dio.httpClientAdapter = adapter;

    // Anonymous GET, cached by CacheInterceptor: this is the entry that used
    // to survive a forced logout.
    await apiClient.get('/public/config');

    final local = AuthLocalDataSourceImpl(
      storageService: storage,
      tokenStore: tokens,
    );
    await local.cacheUser(
      const UserModel(id: 'user-1', email: 'user@example.com'),
    );
    await local.cacheToken('access-token');
    await local.cacheRefreshToken('refresh-token');

    // Guard against a vacuous test: the seed really is non-empty.
    expect(storage.cachedBodyKeys, hasLength(1));
    expect(storage.values.containsKey('http_cache_index'), isTrue);
    expect(storage.values.containsKey(AppConstants.userDataKey), isTrue);
    expect(tokens.accessToken, isNotNull);

    return _World(storage, tokens, apiClient, adapter, local);
  }

  /// Drives an authenticated GET that 401s, which is what forces the logout.
  ///
  /// `.timeout` makes a handler that is never completed fail fast instead of
  /// hanging until the suite-level timeout.
  Future<void> drive401(_World world, {Map<String, String>? headers}) async {
    await expectLater(
      world.apiClient
          .get('/users/me', headers: headers)
          .timeout(const Duration(seconds: 10)),
      throwsA(isA<AppException>()),
      reason: 'the 401 must still surface to the caller',
    );
  }

  group('forced logout empties the HTTP response cache (#114)', () {
    test('criterion 1: a 401 whose refresh fails clears the cache', () async {
      final world = await seedSignedInWorld();

      await drive401(world);

      expect(world.adapter.hits, 2, reason: 'seed GET plus the 401 GET');
      expect(
        world.storage.cachedBodyKeys,
        isEmpty,
        reason: 'cached bodies must not survive a forced logout',
      );
      expect(
        world.storage.values.keys.where((k) => k.startsWith('http_cache_')),
        isEmpty,
        reason: 'timestamps and the index must go too',
      );
      // The rest of the teardown still happened.
      expect(world.tokens.accessToken, isNull);
      expect(world.storage.values.containsKey(AppConstants.userDataKey), false);
    });

    test(
      'criterion 2: the same holds when there is no refresh token at all',
      () async {
        final world = await seedSignedInWorld(
          // No refresh token on the device: the real repository short-circuits
          // to this failure without ever calling the network.
          refreshToken: () async => _refreshUnavailable,
        );
        await world.tokens.clearRefreshToken();

        await drive401(world);

        expect(world.storage.cachedBodyKeys, isEmpty);
        expect(
          world.storage.values.keys.where((k) => k.startsWith('http_cache_')),
          isEmpty,
        );
      },
    );

    test(
      'criterion 2 (second call site): the retry-exhausted early logout at '
      'auth_interceptor.dart clears the cache before rejecting',
      () async {
        // A request already carrying X-Retry-Count: 1 takes the early
        // `_logoutUser()` branch, which returns before the refresh attempt.
        final world = await seedSignedInWorld(
          refreshToken: () async =>
              fail('the early logout branch must not attempt a refresh'),
        );

        await drive401(world, headers: <String, String>{'X-Retry-Count': '1'});

        expect(world.storage.cachedBodyKeys, isEmpty);
        expect(
          world.storage.values.keys.where((k) => k.startsWith('http_cache_')),
          isEmpty,
        );
      },
    );
  });

  group('the two logout paths are equivalent (#114 criterion 3)', () {
    test(
      'explicit logout() and forced _logoutUser() leave identical device state',
      () async {
        // Two worlds seeded by the same function, so any difference in the
        // final snapshots is attributable to the logout path alone.
        final explicitWorld = await seedSignedInWorld();
        final forcedWorld = await seedSignedInWorld();

        // Same starting point, asserted rather than assumed.
        expect(
          forcedWorld.state,
          equals(explicitWorld.state),
          reason:
              'the two worlds must start identical for the comparison to '
              'mean anything',
        );
        final seeded = explicitWorld.state;

        // Path A: the user taps "log out".
        final repository = AuthRepositoryImpl(
          remoteDataSource: _StubRemoteDataSource(),
          localDataSource: explicitWorld.local,
          httpCache: explicitWorld.apiClient.responseCache,
        );
        expect((await repository.logout()).isSuccess, isTrue);

        // Path B: the session expires and a 401 forces the logout.
        await drive401(forcedWorld);

        // The single comparative assertion this criterion exists for.
        expect(
          forcedWorld.state,
          equals(explicitWorld.state),
          reason:
              'forced logout must leave exactly what explicit logout '
              'leaves',
        );

        // And the shared result is actually a torn-down session, not just two
        // matching but wrong states.
        expect(explicitWorld.state, isNot(equals(seeded)));
        expect(explicitWorld.state, <String, Object?>{
          'keyValueStore': <String, Object?>{},
          'accessToken': null,
          'refreshToken': null,
        });
      },
    );
  });

  group('cache clearing is best-effort (#114 criterion 4)', () {
    test('a throwing clearCache() still completes the handler', () async {
      final world = await seedSignedInWorld();
      final failingCache = _FailingResponseCache();
      // Replaces the cache wired by ApiClient; the interceptor instance is the
      // one installed on this client.
      world.apiClient.dio.interceptors
          .whereType<AuthInterceptor>()
          .single
          .attachResponseCache(failingCache);

      await drive401(world);

      expect(failingCache.clearCalls, 1);
      // The earlier steps of the teardown were not rolled back by the throw.
      expect(world.tokens.accessToken, isNull);
      expect(world.storage.values.containsKey(AppConstants.userDataKey), false);
    });
  });

  group('the cache dependency is optional (#114 criterion 5)', () {
    test(
      'an AuthInterceptor with no cache attached still forces a clean logout',
      () async {
        // `ApiClient` always wires one, so this is the hand-built call site:
        // an interceptor used standalone, as several tests in this repo do.
        final tokens = _InMemoryTokenStore();
        await tokens.setAccessToken('access-token');
        await tokens.setRefreshToken('refresh-token');

        final dio = Dio()
          ..httpClientAdapter = _ScriptedAdapter(const [
            _Reply(401, {'error': 'token expired'}),
          ])
          ..interceptors.add(
            AuthInterceptor(
              tokenStore: tokens,
              refreshToken: () async => _refreshUnavailable,
            ),
          );

        await expectLater(
          dio
              .get<dynamic>('http://localhost/users/me')
              .timeout(const Duration(seconds: 10)),
          throwsA(isA<DioException>()),
        );
        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, isNull);
      },
    );
  });
}
