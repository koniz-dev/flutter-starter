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

  /// When set, logout calls wait for it.
  Completer<void>? holdLogout;

  @override
  Future<void> logout({String? refreshToken}) async {
    logouts.add(refreshToken);
    await holdLogout?.future;
  }

  @override
  Future<AuthResponseModel> refreshToken(String refreshToken) =>
      throw UnimplementedError();
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
      // The store holds the second session, whose access token the revoke
      // would carry: it is not sent.
      expect(remote.logouts, isEmpty);
      expect(tokens.accessToken, 'second-access');
    },
  );

  test('a sign-in during a pending logout keeps its credentials', () async {
    tokens
      ..accessToken = 'old-access'
      ..refreshToken = 'old-refresh';
    remote.holdLogout = Completer<void>();
    final logout = repository.logout();
    await Future<void>.delayed(Duration.zero);

    final signIn = repository.login('a@b.c', 'pw');
    await Future<void>.delayed(Duration.zero);
    expect(remote.replies, isEmpty, reason: 'it waits for the teardown');

    remote.holdLogout!.complete();
    await logout;
    await Future<void>.delayed(Duration.zero);
    remote.replies.single.complete(_pair('a'));

    expect(await signIn, isA<Success<Object?>>());
    expect(tokens.accessToken, 'a-access');
    expect(tokens.refreshToken, 'a-refresh');
    expect(remote.logouts, ['old-refresh']);
  });
}
