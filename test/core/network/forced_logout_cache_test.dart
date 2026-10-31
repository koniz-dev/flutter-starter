// Forced logout - the 401 path through AuthInterceptor - must leave the same
// device state as explicit AuthRepositoryImpl.logout().
//
// Regression cover. Before the fix,
// `AuthInterceptor._logoutUser()` cleared the tokens and the cached user blob
// but held no reference to the HTTP response cache, so a session that ended by
// token expiry left cached bodies on the device while a session the user ended
// by tapping "log out" did not. The design says a logout clears the cache;
// only one of the two logout paths implemented that decision.
//
// Scope of the leak, stated honestly: `CacheInterceptor` also refuses
// to store authenticated responses, so what forced logout left behind is
// anonymous-scope entries - which still must not outlive a session boundary,
// and which the sample code here can produce today (see the seeded `/public`
// GET below).
//
// Counterfactual, actually run (evidence:docs/verification/issue-114/counterfactual.log):
// with `attachResponseCache` never called from `ApiClient._createDio` - i.e.
// pre-fix wiring, the interceptor holding no cache - 4 of these 6 tests fail,
// including the equivalence test, which reports the surviving `http_cache_*`
// keys as the difference between the two paths.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/contracts/network_contracts.dart';
import 'package:flutter_starter/core/contracts/state_boundary_contracts.dart';
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
import 'package:flutter_starter/features/auth/domain/auth_error_codes.dart';
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

/// An [_InMemoryStorage] whose removal of the cached user blob always throws.
///
/// One failure injectable into *both* logout paths: the forced path removes
/// that key directly in `AuthInterceptor._logoutUser()`, the explicit path
/// removes it inside `AuthLocalDataSourceImpl.clearCache()`. Every other key -
/// including every `http_cache_*` entry, which `CacheInterceptor.clearCache()`
/// removes one at a time - is untouched, so the only difference the comparison
/// can report is a step one path skipped and the other did not.
class _BlobRemovalFailsStorage extends _InMemoryStorage {
  _BlobRemovalFailsStorage(this.thrown);

  /// Thrown on the user-blob key only. Exercised with an `Exception` and an
  /// `Error`, because `clearCache()`'s old `on Exception` clause handled only
  /// one of the two.
  final Object thrown;

  @override
  Future<bool> remove(String key) async {
    if (key == AppConstants.userDataKey) {
      // Typed `Object` on purpose: both logout paths have to survive an
      // `Error` here as well as an `Exception`, so the lint's premise does
      // not hold.
      // ignore: only_throw_errors
      throw thrown;
    }
    return await super.remove(key);
  }
}

/// Counts how often a forced logout told the running app its session ended.
class _CountingSessionSink implements ISessionTerminationSink {
  int calls = 0;

  @override
  void onSessionTerminated() => calls++;
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
  Future<void> logout({String? refreshToken}) async => logoutCalls++;

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
    _InMemoryStorage? storageOverride,
    ISessionTerminationSink? sessionSink,
  }) async {
    final storage = storageOverride ?? _InMemoryStorage();
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
        // Wired with the two dependencies that write to the device, so the
        // cached user blob is part of the state under comparison.
        //
        // This is *not* the full `authInterceptorProvider` wiring, and saying
        // so used to be wrong. Two
        // constructor arguments are deliberately omitted:
        //
        // - `sessionSink:`. The in-memory session is real state, but
        //   `AuthRepositoryImpl.logout()` - the explicit path this file
        //   compares against - holds no `ISessionTerminationSink` at all; on
        //   that path `AuthNotifier` drops the session itself, a layer above
        //   anything `_World` models. Putting the sink in `_World.state`
        //   would therefore compare a concern only one of the two paths owns
        //   here, and would report a difference that is an artifact of where
        //   the boundary sits rather than of a logout step being skipped.
        //   `test/core/network/forced_logout_session_test.dart` covers the
        //   sink on the forced path, with its own counterfactual.
        // - `sessionGeneration:`. Production shares one counter
        //   between the interceptor and the repository; here each gets its
        //   own default. It orders concurrent credential *writes* and leaves
        //   no trace in the persisted state this file snapshots.
        keyValueStore: storage,
        sessionSink: sessionSink,
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
      throwsA(
        isA<ServerException>().having((e) => e.statusCode, 'statusCode', 401),
      ),
      reason: 'the 401 must still surface to the caller',
    );
  }

  group('forced logout empties the HTTP response cache', () {
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
      'criterion 2 (second call site): a replay the server refuses with 401 '
      'clears the cache before rejecting',
      () async {
        // The refresh succeeds, and the server then refuses the token it just
        // issued: the replay's 401 is the other `_logoutUser()` call site.
        // (It replaced the X-Retry-Count branch, since removed.)
        final world = await seedSignedInWorld(
          refreshToken: () async => const Success('fresh-access-token'),
          replies: const [
            _Reply(200, {'motd': 'cached-before-logout'}),
            _Reply(401, {'error': 'token expired'}),
            _Reply(401, {'error': 'token refused'}),
          ],
        );

        await drive401(world);

        expect(world.storage.cachedBodyKeys, isEmpty);
        expect(
          world.storage.values.keys.where((k) => k.startsWith('http_cache_')),
          isEmpty,
        );
      },
    );
  });

  group('the two logout paths are equivalent', () {
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

    // The happy-path comparison
    // above never exercises a teardown step that throws, which is exactly
    // where the two paths had diverged: `_logoutUser()` guards each step
    // separately, while the explicit path chained them inside one `try`, so
    // the first throw skipped everything after it.
    //
    // Counterfactual, actually run
    // (evidence:docs/verification/issue-168/counterfactual.log): against the pre-fix
    // chained bodies both cases below fail, reporting the surviving tokens and
    // `http_cache_*` keys as the difference between the two paths.
    for (final failure in <({String label, Object thrown})>[
      (label: 'an Exception', thrown: const CacheException('prefs locked')),
      (label: 'an Error', thrown: StateError('prefs plugin missing')),
    ]) {
      test(
        'the two paths stay equivalent when the user-blob removal throws '
        '${failure.label}',
        () async {
          // The same injected failure on both sides, so any difference in the
          // final snapshots is again attributable to the logout path alone.
          final explicitWorld = await seedSignedInWorld(
            storageOverride: _BlobRemovalFailsStorage(failure.thrown),
          );
          final forcedWorld = await seedSignedInWorld(
            storageOverride: _BlobRemovalFailsStorage(failure.thrown),
          );

          expect(
            forcedWorld.state,
            equals(explicitWorld.state),
            reason: 'the two worlds must start identical',
          );
          final seeded = explicitWorld.state;

          // Path A: the user taps "log out". The teardown fails, and says so.
          final repository = AuthRepositoryImpl(
            remoteDataSource: _StubRemoteDataSource(),
            localDataSource: explicitWorld.local,
            httpCache: explicitWorld.apiClient.responseCache,
          );
          final result = await repository.logout();
          expect(
            result.isFailure,
            isTrue,
            reason:
                'a teardown step that failed must not be reported as a '
                'clean logout',
          );

          // Path B: the session expires and a 401 forces the logout.
          await drive401(forcedWorld);

          // The assertion this criterion exists for.
          expect(
            forcedWorld.state,
            equals(explicitWorld.state),
            reason:
                'a failing teardown step must leave the same device state on '
                'both paths - the steps after it run either way',
          );

          // And that shared state is a torn-down session apart from the one
          // key whose removal was rigged to fail, rather than two matching
          // but wrong states.
          expect(explicitWorld.state, isNot(equals(seeded)));
          expect(explicitWorld.tokens.accessToken, isNull);
          expect(explicitWorld.tokens.refreshToken, isNull);
          expect(
            explicitWorld.storage.values.keys.where(
              (k) => k.startsWith('http_cache_'),
            ),
            isEmpty,
            reason: 'the HTTP cache is the step the explicit path used to skip',
          );
          expect(
            explicitWorld.storage.values.keys,
            <String>[AppConstants.userDataKey],
            reason:
                'only the key whose removal was rigged to throw may survive',
          );
        },
      );
    }
  });

  group('cache clearing is best-effort', () {
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

  group('the cache dependency is optional', () {
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

  // AuthInterceptor used to treat every failed
  // refresh as fatal, so one 401 that coincided with a timeout or a 503 on
  // the refresh endpoint wiped the tokens, the cached user and the HTTP cache
  // and signed the user out - although AuthRepositoryImpl tags exactly the
  // failures that mean the refresh token is dead, and leaves transport
  // trouble untagged so the session survives it.
  group('a transient refresh failure leaves the session alone', () {
    for (final (label, failure) in const [
      (
        'criterion 1: a RECEIVE_TIMEOUT',
        NetworkFailure('Receive timeout', code: 'RECEIVE_TIMEOUT'),
      ),
      (
        'criterion 2: a 503',
        ServerFailure('Service unavailable. Please try again later.'),
      ),
    ]) {
      test(
        '$label leaves tokens, user blob, HTTP cache and session intact',
        () async {
          final sink = _CountingSessionSink();
          final world = await seedSignedInWorld(
            refreshToken: () async => ResultFailure<String>(failure),
            sessionSink: sink,
          );
          final before = world.state;

          final thrown = await world.apiClient
              .get('/users/me')
              .then<Object?>((_) => null, onError: (Object e) => e)
              .timeout(const Duration(seconds: 10));

          expect(world.state, before, reason: 'nothing was torn down');
          expect(world.tokens.accessToken, 'access-token');
          expect(world.tokens.refreshToken, 'refresh-token');
          expect(world.storage.cachedBodyKeys, hasLength(1));
          expect(
            world.storage.values.containsKey(AppConstants.userDataKey),
            isTrue,
          );
          expect(sink.calls, 0, reason: 'the in-memory session stays up');
          expect(
            thrown,
            isA<NetworkException>().having(
              (e) => e.message,
              'message',
              contains(failure.message),
            ),
            reason: 'the caller fails, with the refresh failure as the cause',
          );
        },
      );
    }

    test(
      'criterion 3: a failure tagged REFRESH_TOKEN_EXPIRED still forces the '
      'full teardown',
      () async {
        final sink = _CountingSessionSink();
        final world = await seedSignedInWorld(
          refreshToken: () async => const ResultFailure<String>(
            AuthFailure(
              'Unauthorized. Please login again.',
              code: AuthErrorCodes.refreshTokenExpired,
            ),
          ),
          sessionSink: sink,
        );

        await drive401(world);

        expect(world.tokens.accessToken, isNull);
        expect(world.tokens.refreshToken, isNull);
        expect(world.storage.cachedBodyKeys, isEmpty);
        expect(
          world.storage.values.containsKey(AppConstants.userDataKey),
          isFalse,
        );
        expect(sink.calls, 1);
      },
    );

    test(
      'the code core matches on is the one the auth slice sets',
      () {
        // Core may not import the feature, so
        // AuthInterceptor carries its own copy of the code. This pins the two
        // together: renaming one without the other fails here.
        expect(
          AuthInterceptor.refreshTokenExpiredCode,
          AuthErrorCodes.refreshTokenExpired,
        );
      },
    );
  });
}
