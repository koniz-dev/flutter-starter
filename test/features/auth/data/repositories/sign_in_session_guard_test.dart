// login() and register() invalidated the session at their start, made the
// round trip, then wrote the user and both tokens without checking again. A
// logout during the round trip was undone by those writes, and of two
// overlapping logins the slower one won. Each write is now checked against
// the session the call started.
//
// A sign-in cut off that way discards its tokens, which expire on the
// server. And a sign-in completed while a logout's server call was still
// pending had its fresh credentials deleted by that logout's teardown; it now
// waits for the teardown.

import 'dart:async';

import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_starter/features/auth/domain/auth_error_codes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/in_memory_stores.dart';

AuthResponseModel _pair(String prefix) => AuthResponseModel.fromJson({
  'user': {'id': prefix, 'email': '$prefix@b.c'},
  'token': '$prefix-access',
  'refresh_token': '$prefix-refresh',
});

/// Each sign-in call waits for the next completer in [replies].
class _Remote implements AuthRemoteDataSource {
  final List<Completer<AuthResponseModel>> replies = [];

  Future<AuthResponseModel> _next() {
    final reply = Completer<AuthResponseModel>();
    replies.add(reply);
    return reply.future;
  }

  @override
  Future<AuthResponseModel> login(String email, String password) => _next();

  @override
  Future<AuthResponseModel> register(
    String email,
    String password,
    String name,
  ) => _next();

  /// The refresh token of every logout call, in order.
  final List<String?> logouts = [];

  /// When true, each logout call waits for its own completer in [holds].
  bool holdLogouts = false;
  final List<Completer<void>> holds = [];

  @override
  Future<void> logout({String? refreshToken}) async {
    logouts.add(refreshToken);
    if (!holdLogouts) return;
    final hold = Completer<void>();
    holds.add(hold);
    await hold.future;
  }

  @override
  Future<AuthResponseModel> refreshToken(String refreshToken) =>
      throw UnimplementedError();
}

/// Lets queued microtasks and zero-delay timers run.
Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _Remote remote;
  late InMemoryTokenStore tokens;
  late InMemoryKeyValueStore storage;
  late AuthRepositoryImpl repository;

  setUp(() {
    remote = _Remote();
    tokens = InMemoryTokenStore();
    storage = InMemoryKeyValueStore();
    repository = AuthRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: AuthLocalDataSourceImpl(
        storageService: storage,
        tokenStore: tokens,
      ),
    );
  });

  void expectStale(Result<Object?> result) => expect(
    (result as ResultFailure).failure,
    isA<Failure>().having(
      (f) => f.code,
      'code',
      AuthErrorCodes.sessionTerminated,
    ),
  );

  for (final (label, start) in <(String, Future<Result<Object?>> Function())>[
    ('login', () => repository.login('a@b.c', 'pw')),
    ('register', () => repository.register('a@b.c', 'pw', 'A')),
  ]) {
    test(
      'a logout during the $label round trip leaves nothing stored',
      () async {
        final signIn = start();
        await Future<void>.delayed(Duration.zero);
        await repository.logout();
        remote.replies.single.complete(_pair('a'));

        final result = await signIn;

        expect(tokens.accessToken, isNull);
        expect(tokens.refreshToken, isNull);
        expect(storage.values, isEmpty, reason: 'no cached user');
        expectStale(result);
      },
    );
  }

  test('of two overlapping logins, the second one stays signed in', () async {
    final first = repository.login('first@b.c', 'pw');
    await Future<void>.delayed(Duration.zero);
    final second = repository.login('second@b.c', 'pw');
    await Future<void>.delayed(Duration.zero);

    // The second answers first, the first afterwards.
    remote.replies[1].complete(_pair('second'));
    await second;
    remote.replies[0].complete(_pair('first'));
    final firstResult = await first;

    expect(tokens.accessToken, 'second-access');
    expect(tokens.refreshToken, 'second-refresh');
    expectStale(firstResult);
  });

  test(
    'a sign-in cut off by a logout stores nothing and revokes nothing',
    () async {
      final signIn = repository.login('a@b.c', 'pw');
      await Future<void>.delayed(Duration.zero);
      await repository.logout();
      remote.replies.single.complete(_pair('a'));

      expectStale(await signIn);
      await _settle();

      // Only the logout's own request: the discarded tokens expire on the
      // server.
      expect(remote.logouts, [null]);
      expect(tokens.accessToken, isNull);
    },
  );

  test('a sign-in during a pending logout keeps its credentials', () async {
    tokens
      ..accessToken = 'old-access'
      ..refreshToken = 'old-refresh';
    remote.holdLogouts = true;
    final logout = repository.logout();
    await Future<void>.delayed(Duration.zero);

    final signIn = repository.login('a@b.c', 'pw');
    await Future<void>.delayed(Duration.zero);
    expect(remote.replies, isEmpty, reason: 'it waits for the teardown');

    remote.holds.single.complete();
    await logout;
    await Future<void>.delayed(Duration.zero);
    remote.replies.single.complete(_pair('a'));

    expect(await signIn, isA<Success<Object?>>());
    expect(tokens.accessToken, 'a-access');
    expect(tokens.refreshToken, 'a-refresh');
    expect(remote.logouts, ['old-refresh']);
  });

  test(
    'a sign-in waits for every pending logout, not only the latest',
    () async {
      tokens
        ..accessToken = 'old-access'
        ..refreshToken = 'old-refresh';
      remote.holdLogouts = true;
      final first = repository.logout();
      await Future<void>.delayed(Duration.zero);
      final second = repository.logout();
      await Future<void>.delayed(Duration.zero);
      remote.holds[1].complete();
      await second;

      final signIn = repository.login('a@b.c', 'pw');
      await _settle();
      expect(remote.replies, isEmpty, reason: 'the first logout still pends');

      remote.holds[0].complete();
      await first;
      await _settle();
      remote.replies.single.complete(_pair('a'));

      expect(await signIn, isA<Success<Object?>>());
      expect(tokens.accessToken, 'a-access');
    },
  );

  test('a logout called right after a login ends that login', () async {
    remote.holdLogouts = true;
    final signIn = repository.login('a@b.c', 'pw');
    final logout = repository.logout();
    await _settle();

    remote.holds.single.complete();
    await logout;
    await _settle();

    expectStale(await signIn);
    expect(remote.replies, isEmpty, reason: 'it never reached the server');
    expect(tokens.accessToken, isNull);
  });

  test(
    'a sign-in gives up after the bound when a logout never finishes',
    () async {
      final bounded = AuthRepositoryImpl(
        remoteDataSource: remote,
        localDataSource: AuthLocalDataSourceImpl(
          storageService: storage,
          tokenStore: tokens,
        ),
        pendingLogoutLimit: const Duration(milliseconds: 20),
      );
      remote.holdLogouts = true;
      unawaited(bounded.logout());
      await Future<void>.delayed(Duration.zero);

      final result = await bounded.login('a@b.c', 'pw');

      expect(
        (result as ResultFailure).failure.code,
        AuthErrorCodes.signOutInProgress,
      );
      expect(remote.replies, isEmpty, reason: 'it never signed in');
      expect(tokens.accessToken, isNull);
    },
  );

  test('a sign-in started by a session listener during a logout waits for '
      'its teardown', () async {
    tokens
      ..accessToken = 'old-access'
      ..refreshToken = 'old-refresh';
    remote.holdLogouts = true;
    Future<Result<Object?>>? signIn;
    var started = false;
    void startSignIn() {
      // The sign-in invalidates too, which calls this again: start once.
      if (started) return;
      started = true;
      signIn = repository.login('a@b.c', 'pw');
    }

    repository.sessionGeneration.addListener(startSignIn);
    addTearDown(() => repository.sessionGeneration.removeListener(startSignIn));

    final logout = repository.logout(); // its invalidate starts the sign-in
    await _settle();
    expect(signIn, isNotNull);
    expect(remote.replies, isEmpty, reason: 'it waits for the teardown');

    remote.holds.single.complete();
    await logout;
    await _settle();
    remote.replies.single.complete(_pair('a'));

    expect(await signIn, isA<Success<Object?>>());
    expect(tokens.accessToken, 'a-access');
  });
}
