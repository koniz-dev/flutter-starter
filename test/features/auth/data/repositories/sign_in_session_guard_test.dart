// login() and register() invalidated the session at their start, made the
// round trip, then wrote the user and both tokens without checking again. A
// logout during the round trip was undone by those writes, and of two
// overlapping logins the slower one won. Each write is now checked against
// the session the call started.
//
// A sign-in cut off that way discarded tokens the server had issued, and
// nothing revoked them; it now asks the server to. And a sign-in completed
// while a logout's server call was still pending had its fresh credentials
// deleted by that logout's teardown; it now waits for the teardown.

import 'dart:async';

import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/session/session_generation.dart';
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

/// Lets fire-and-forget work (the revoke) run.
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
    'a sign-in cut off by a logout asks the server to revoke its token',
    () async {
      final signIn = repository.login('a@b.c', 'pw');
      await Future<void>.delayed(Duration.zero);
      await repository.logout();
      remote.replies.single.complete(_pair('a'));

      expectStale(await signIn);
      await _settle();

      // The logout revoked what was stored then (nothing); the discarded
      // sign-in revokes its own refresh token.
      expect(remote.logouts, [null, 'a-refresh']);
      expect(tokens.accessToken, isNull);
    },
  );

  test('a sign-in that is not cut off revokes nothing', () async {
    final signIn = repository.login('a@b.c', 'pw');
    await Future<void>.delayed(Duration.zero);
    remote.replies.single.complete(_pair('a'));

    expect(await signIn, isA<Success<Object?>>());
    await _settle();
    expect(remote.logouts, isEmpty);
  });

  test(
    'a sign-in replaced by another one does not revoke as the winner',
    () async {
      final first = repository.login('first@b.c', 'pw');
      await Future<void>.delayed(Duration.zero);
      final second = repository.login('second@b.c', 'pw');
      await Future<void>.delayed(Duration.zero);
      remote.replies[1].complete(_pair('second'));
      await second;
      remote.replies[0].complete(_pair('first'));

      expectStale(await first);
      await _settle();
      // The store holds the second session, whose access token the revoke
      // would carry: it is not sent.
      expect(remote.logouts, isEmpty);
      expect(tokens.accessToken, 'second-access');
    },
  );

  test(
    'a sign-in replaced before the newer one stores does not revoke either',
    () async {
      final first = repository.login('first@b.c', 'pw');
      await _settle();
      final second = repository.login('second@b.c', 'pw');
      await _settle();
      // Both answer in the same tick, the first one first: when it finds
      // itself stale, the store is still empty, but a later sign-in has
      // started, and the revoke would go out with its token.
      remote.replies[0].complete(_pair('first'));
      remote.replies[1].complete(_pair('second'));

      expectStale(await first);
      expect(await second, isA<Success<Object?>>());
      await _settle();
      expect(remote.logouts, isEmpty);
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

  test('a revoke waits for a logout still tearing down', () async {
    tokens
      ..accessToken = 'old-access'
      ..refreshToken = 'old-refresh';
    remote.holdLogouts = true;
    final signIn = repository.login('a@b.c', 'pw');
    await _settle();
    final logout = repository.logout();
    await _settle();
    // The sign-in's reply arrives while the logout's server call is held:
    // the old session's token is still stored.
    remote.replies.single.complete(_pair('a'));
    expectStale(await signIn);
    await _settle();
    expect(remote.logouts, ['old-refresh'], reason: 'not sent yet');

    remote.holds.single.complete();
    await logout;
    await _settle();

    expect(remote.logouts, ['old-refresh', 'a-refresh']);
  });

  test('no revoke goes out while a session still holds the store', () async {
    // The interceptor's forced logout ends the session through the shared
    // generation, and clears the store only afterwards.
    final generation = SessionGeneration();
    final shared = AuthRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: AuthLocalDataSourceImpl(
        storageService: storage,
        tokenStore: tokens,
      ),
      sessionGeneration: generation,
    );
    final signIn = shared.login('a@b.c', 'pw');
    await _settle();
    tokens
      ..accessToken = 'other-access'
      ..refreshToken = 'other-refresh';
    generation.invalidate();
    remote.replies.single.complete(_pair('a'));

    expectStale(await signIn);
    await _settle();
    expect(remote.logouts, isEmpty, reason: 'it would carry other-access');
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
}
