// Regression cover for koniz-dev/flutter-starter#169.
//
// A logout that landed while a token refresh was in flight used to be silently
// undone: the refresh resolved *after* the teardown and re-persisted a live
// access token **and** refresh token onto a device that was signed out on
// screen. Three unconditional writes sat behind one network round trip -
// `cacheToken` and `cacheRefreshToken` inside `AuthRepositoryImpl.refreshToken`
// and `setAccessToken` inside `AuthInterceptor._handle401Error` - and none of
// them re-checked whether the session still existed.
//
// Shaped after the probe the security phase reproduced it with, and built
// deliberately from the **real** objects on both sides of that round trip: a
// real `AuthInterceptor` on a real `Dio`, a real `AuthRepositoryImpl` and a
// real `AuthLocalDataSourceImpl` sharing one token store, and a real
// `AuthRepositoryImpl.logout()` as the teardown. Only the two things that
// would otherwise reach the network or a platform channel are swapped: the
// remote data source and the transport. A test whose refresh callback was a
// hand-written stub could not see the two repository writes at all, which is
// exactly where two thirds of the bug lived.
//
// Nothing here synchronises on wall-clock time (the lesson of #121): the
// refresh is held open by a `Completer` the test releases, so "the logout
// happened while the refresh was in flight" is a happens-before rather than a
// bet on machine load. Both storage fakes are in-memory, because an unmocked
// SharedPreferences or Keychain channel makes `flutter test` hang rather than
// fail.
//
// Counterfactual, actually run and recorded in
// docs/verification/issue-169/counterfactual.log: with the three
// `isCurrent(...)` guards removed and nothing else changed, six of these eight
// tests fail, the first of them reporting the security phase's own probe
// output - `Expected: null / Actual: 'NEW-access-1'`.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/session/session_generation.dart';
import 'package:flutter_starter/core/session/session_providers.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';
import 'package:flutter_starter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/in_memory_stores.dart';

/// The user whose session every test below starts from.
const _seededUser = UserModel(
  id: 'u-1',
  email: 'signed-in@example.com',
  name: 'Signed In',
);

/// Transport that replies from a scripted queue and records every request.
///
/// The last scripted reply repeats once the queue is exhausted.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._replies);

  final List<ResponseBody Function()> _replies;

  /// Every request this transport was asked to send, in order.
  final List<RequestOptions> sent = [];

  /// How many requests reached this transport.
  int get hits => sent.length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final index = sent.length < _replies.length
        ? sent.length
        : _replies.length - 1;
    sent.add(options);
    return _replies[index]();
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody Function() _json(int statusCode, Map<String, dynamic> body) {
  return () => ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

/// The auth server, minus the network.
///
/// Every reply is a success: the danger this file is about is a refresh that
/// *worked* landing after the session it belonged to ended.
class _ScriptedRemote implements AuthRemoteDataSource {
  /// Awaited at the top of [refreshToken]; how a test holds the round trip
  /// open across a logout.
  Future<void> Function(int call)? onRefresh;

  /// How many refreshes the server was asked for.
  int refreshCalls = 0;

  /// How many times `/auth/logout` was called.
  int logoutCalls = 0;

  @override
  Future<AuthResponseModel> login(String email, String password) async {
    return const AuthResponseModel(
      user: _seededUser,
      token: 'session-2-access',
      refreshToken: 'session-2-refresh',
    );
  }

  @override
  Future<AuthResponseModel> register(
    String email,
    String password,
    String name,
  ) async {
    return const AuthResponseModel(
      user: _seededUser,
      token: 'session-2-access',
      refreshToken: 'session-2-refresh',
    );
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
  }

  @override
  Future<AuthResponseModel> refreshToken(String refreshToken) async {
    refreshCalls++;
    final call = refreshCalls;
    await onRefresh?.call(call);
    return AuthResponseModel(
      user: _seededUser,
      token: 'NEW-access-$call',
      refreshToken: 'NEW-refresh-$call',
    );
  }
}

/// Awaits [future] and returns the error it threw, or null on success.
Future<Object?> _settle(Future<Response<dynamic>> future) async {
  try {
    await future;
    return null;
  } on Object catch (error) {
    return error;
  }
}

/// A future that must not outlive [seconds]; a hang fails the test instead of
/// stalling the whole suite.
///
/// A deadline, not a synchronisation mechanism: no assertion depends on how
/// much of it elapses.
Future<T> _within<T>(Future<T> future, {int seconds = 5}) {
  return future.timeout(Duration(seconds: seconds));
}

/// An [AuthInterceptor] that announces when its 401 handling has processed a
/// given number of errors.
///
/// The same structural rendezvous `auth_interceptor_refresh_queue_test.dart`
/// uses: `super.onError` reaches the `_isRefreshing` single-flight guard with
/// no `await` in between, so awaiting [seen] means "the guard has processed N
/// 401s" rather than "enough milliseconds have passed". The override only
/// counts; every behaviour under test is `super`'s.
class _CountingAuthInterceptor extends AuthInterceptor {
  _CountingAuthInterceptor({
    required super.refreshToken,
    super.tokenStore,
    super.keyValueStore,
    super.retryDioFactory,
    super.sessionGeneration,
  });

  int _errorsSeen = 0;
  final Map<int, Completer<void>> _marks = {};

  /// Completes once [count] errors have been through 401 handling.
  Future<void> seen(int count) {
    if (_errorsSeen >= count) {
      return Future<void>.value();
    }
    return (_marks[count] ??= Completer<void>()).future;
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) {
    // super first: it is what queues this request or starts the refresh, and
    // it does so synchronously, before returning.
    final handled = super.onError(err, handler);
    _errorsSeen++;
    final mark = _marks[_errorsSeen];
    if (mark != null && !mark.isCompleted) {
      mark.complete();
    }
    return handled;
  }
}

void main() {
  group('a logout landing during an in-flight refresh', () {
    late InMemoryTokenStore tokens;
    late InMemoryStorage storage;
    late SessionGeneration generation;
    late _ScriptedRemote remote;
    late AuthRepositoryImpl repository;
    late _ScriptedAdapter mainAdapter;
    late _ScriptedAdapter retryAdapter;
    late _CountingAuthInterceptor interceptor;
    late Dio dio;

    setUp(() {
      tokens = InMemoryTokenStore()
        ..accessToken = 'live-access'
        ..refreshToken = 'live-refresh';
      storage = InMemoryStorage();
      storage.values[AppConstants.userDataKey] = jsonEncode(
        _seededUser.toJson(),
      );
      generation = SessionGeneration();
      remote = _ScriptedRemote();
      repository = AuthRepositoryImpl(
        remoteDataSource: remote,
        localDataSource: AuthLocalDataSourceImpl(
          storageService: storage,
          tokenStore: tokens,
        ),
        sessionGeneration: generation,
      );

      // Every request 401s unless a test scripts otherwise; every replay 200s.
      mainAdapter = _ScriptedAdapter([
        _json(401, {'message': 'Unauthorized'}),
      ]);
      retryAdapter = _ScriptedAdapter([
        _json(200, {'replayed': true}),
      ]);

      interceptor = _CountingAuthInterceptor(
        tokenStore: tokens,
        keyValueStore: storage,
        // The production wiring: the interceptor's refresh *is* the
        // repository's, so both of the repository's writes are in scope.
        refreshToken: repository.refreshToken,
        // The one instance both sides share, as `sessionGenerationProvider`
        // supplies in the app.
        sessionGeneration: generation,
        retryDioFactory: () => Dio()..httpClientAdapter = retryAdapter,
      );
      dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
        ..httpClientAdapter = mainAdapter
        ..interceptors.add(interceptor);
    });

    /// Holds the next refresh open until the returned completer is completed,
    /// and reports when the server has been reached.
    ({Completer<void> started, Completer<void> release}) holdRefreshOpen() {
      final started = Completer<void>();
      final release = Completer<void>();
      remote.onRefresh = (call) async {
        if (!started.isCompleted) {
          started.complete();
        }
        await release.future;
      };
      return (started: started, release: release);
    }

    test(
      'criterion 1+2: neither token is re-persisted, through the real '
      'repository refresh and the real logout',
      () async {
        final gate = holdRefreshOpen();

        final pending = _settle(dio.get<dynamic>('/profile'));
        await _within(gate.started.future);

        // The user taps "log out" while the refresh is open. Real teardown:
        // remote logout, cached user blob, both tokens.
        final logoutResult = await repository.logout();
        expect(logoutResult.isSuccess, isTrue);
        expect(remote.logoutCalls, 1);
        // The teardown provably completed *before* the refresh resolved.
        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, isNull);

        gate.release.complete();
        final outcome = await _within(pending);

        // The server did answer; the response simply must not be persisted.
        expect(remote.refreshCalls, 1);
        // Asserted first, and in this order, so a counterfactual run reports
        // the same two lines the security phase's probe reported.
        expect(
          tokens.accessToken,
          isNull,
          reason: 'a logged-out device must hold no access token',
        );
        expect(
          tokens.refreshToken,
          isNull,
          reason: 'a refresh token outliving an explicit logout is #52 again',
        );
        // Nothing was replayed with the dead session's credentials...
        expect(retryAdapter.hits, 0);
        // ...and the request that triggered the refresh still completed rather
        // than hanging - rejection is completion (#59 still holds).
        expect(outcome, isA<DioException>());
      },
    );

    test(
      'criterion 3: queued requests are rejected, not replayed, when the '
      'session ended during the refresh',
      () async {
        final gate = holdRefreshOpen();

        final first = _settle(dio.get<dynamic>('/profile'));
        await _within(gate.started.future);
        final second = _settle(dio.get<dynamic>('/tasks'));
        final third = _settle(dio.get<dynamic>('/settings'));
        // Structural: returns only once all three 401s are through the
        // single-flight guard, so the last two are provably queued.
        await _within(interceptor.seen(3));
        expect(remote.refreshCalls, 1);

        await repository.logout();
        gate.release.complete();

        final outcomes = await _within(Future.wait([first, second, third]));

        // The criterion itself: no queued request reached the transport with
        // the post-logout token.
        expect(
          retryAdapter.hits,
          0,
          reason:
              'a drained request put the previous session on the wire after '
              'logout',
        );
        // Every handler completed; none was left dangling (#59 still holds),
        // and all three were rejected rather than resolved.
        expect(outcomes, hasLength(3));
        expect(outcomes.whereType<DioException>(), hasLength(3));
        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, isNull);
      },
    );

    test(
      'criterion 4: the retryCount == 1 forced logout survives a refresh '
      'already in flight',
      () async {
        final gate = holdRefreshOpen();

        // First 401 starts the refresh and holds it open.
        final first = _settle(dio.get<dynamic>('/profile'));
        await _within(gate.started.future);

        // A second request arrives already carrying X-Retry-Count: 1, so its
        // 401 takes the "already retried once" branch and forces a logout
        // through `_logoutUser()` rather than through the repository.
        final secondError = await _within(
          _settle(
            dio.get<dynamic>(
              '/tasks',
              options: Options(headers: {'X-Retry-Count': '1'}),
            ),
          ),
        );
        expect(secondError, isA<DioException>());
        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, isNull);
        // The forced logout cleared the cached user blob too, as before.
        expect(storage.values[AppConstants.userDataKey], isNull);

        // Now the refresh that was already in flight comes back.
        gate.release.complete();
        await _within(first);

        expect(
          tokens.accessToken,
          isNull,
          reason: 'the forced logout was overwritten by the in-flight refresh',
        );
        expect(tokens.refreshToken, isNull);
        expect(retryAdapter.hits, 0);
      },
    );

    test(
      'the guard does not lean on the cached user blob: after a stale '
      'refresh there is no token, so no session can be restored',
      () async {
        final gate = holdRefreshOpen();

        final pending = _settle(dio.get<dynamic>('/profile'));
        await _within(gate.started.future);
        await repository.logout();
        gate.release.complete();
        await _within(pending);

        // Put the user blob back by hand. #85's second check - "a session
        // needs the blob as well as the token" - is now doing nothing, and
        // the device is still signed out on the strength of the token alone.
        storage.values[AppConstants.userDataKey] = jsonEncode(
          _seededUser.toJson(),
        );

        final authenticated = await repository.isAuthenticated();
        expect(authenticated, isA<Success<bool>>());
        expect((authenticated as Success<bool>).data, isFalse);

        final current = await repository.getCurrentUser();
        expect((current as Success<User?>).data, isNull);
      },
    );

    test(
      'criterion 1: a refresh that resolves inside its own session still '
      'persists both tokens',
      () async {
        final outcome = await _within(_settle(dio.get<dynamic>('/profile')));

        // The guard must not break the path it guards.
        expect(outcome, isNull);
        expect(tokens.accessToken, 'NEW-access-1');
        expect(tokens.refreshToken, 'NEW-refresh-1');
        expect(retryAdapter.hits, 1);
      },
    );

    test(
      'criterion 5: the interceptor refreshes normally again after a '
      'subsequent login',
      () async {
        final gate = holdRefreshOpen();

        // Session 1: 401, refresh held open, user logs out.
        final first = _settle(dio.get<dynamic>('/profile'));
        await _within(gate.started.future);
        await repository.logout();
        gate.release.complete();
        await _within(first);
        expect(tokens.accessToken, isNull);

        // Session 2: the user signs back in through the real repository.
        remote.onRefresh = null;
        final login = await repository.login('a@b.test', 'pw');
        expect(login.isSuccess, isTrue);
        expect(tokens.accessToken, 'session-2-access');

        // A 401 in the new session must refresh and persist as normal.
        final second = await _within(_settle(dio.get<dynamic>('/tasks')));

        expect(second, isNull, reason: 'the guard wedged refresh permanently');
        expect(remote.refreshCalls, 2);
        expect(tokens.accessToken, 'NEW-access-2');
        expect(tokens.refreshToken, 'NEW-refresh-2');
      },
    );

    test(
      'a login completing during an old refresh keeps the new session: the '
      'stale refresh skips its writes rather than undoing them',
      () async {
        final gate = holdRefreshOpen();

        final pending = _settle(dio.get<dynamic>('/profile'));
        await _within(gate.started.future);

        // Logout and a fresh sign-in, both inside the refresh window. This is
        // why the guard is a generation counter and not a `terminated` flag,
        // and why a stale refresh must not *clear* the store either.
        await repository.logout();
        remote.onRefresh = null;
        await repository.login('a@b.test', 'pw');
        expect(tokens.accessToken, 'session-2-access');

        gate.release.complete();
        await _within(pending);

        expect(
          tokens.accessToken,
          'session-2-access',
          reason: "a stale refresh must not touch a newer session's tokens",
        );
        expect(tokens.refreshToken, 'session-2-refresh');
        expect(retryAdapter.hits, 0);
      },
    );
  });

  group('the real provider graph shares one SessionGeneration', () {
    test(
      'a forced logout raised inside AuthInterceptor advances the counter '
      'AuthRepositoryImpl checks',
      () async {
        final storage = InMemoryStorage();
        final tokens = InMemoryTokenStore();
        final container = ProviderContainer(
          overrides: [
            // The production seam wiring (koniz-dev/flutter-starter#221):
            // without it the interceptor's refresh never reaches the real
            // repository and this test would prove less than it reads.
            ...authModuleOverrides,
            storageServiceProvider.overrideWithValue(storage),
            tokenStoreProvider.overrideWithValue(tokens),
          ],
        );
        addTearDown(container.dispose);

        // Persist a session as a login does, but with no refresh token: the
        // refresh then fails inside real production code without touching the
        // network, which is the forced-logout half of the 401 path.
        final local = container.read(authLocalDataSourceProvider);
        await local.cacheUser(_seededUser);
        await local.cacheToken('access-token');

        final shared = container.read(sessionGenerationProvider);
        final before = shared.current;

        // Half of the wiring, asserted directly.
        final repository =
            container.read(authRepositoryProvider) as AuthRepositoryImpl;
        expect(identical(repository.sessionGeneration, shared), isTrue);

        // The other half is private to the interceptor, so it is asserted
        // through behaviour: only an interceptor holding *this* instance can
        // move this counter.
        final apiClient = container.read(apiClientProvider)
          ..dio.httpClientAdapter = _ScriptedAdapter([
            _json(401, {'message': 'Unauthorized'}),
          ]);

        await expectLater(
          apiClient.get('/users/me').timeout(const Duration(seconds: 10)),
          throwsA(isA<AppException>()),
        );

        expect(
          shared.current,
          greaterThan(before),
          reason:
              'authInterceptorProvider built an interceptor with its own '
              'counter, so a logout it raises is invisible to the repository',
        );
        expect(tokens.accessToken, isNull);
      },
    );
  });

  group('SessionGeneration', () {
    test('a generation left behind never becomes current again', () {
      final generation = SessionGeneration();
      final first = generation.current;
      expect(generation.isCurrent(first), isTrue);

      generation.invalidate();
      expect(generation.isCurrent(first), isFalse);

      // The case a bool `terminated` flag gets wrong: starting a new session
      // must not resurrect an older generation.
      final second = generation.current;
      generation.invalidate();
      expect(generation.isCurrent(first), isFalse);
      expect(generation.isCurrent(second), isFalse);
      expect(generation.isCurrent(generation.current), isTrue);
    });
  });
}
