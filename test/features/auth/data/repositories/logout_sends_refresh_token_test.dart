// Logout posted no body, so the server could not tell which refresh token to
// revoke, and an expired access token made the call 401 (/auth/logout is not
// refreshed). A refresh token copied earlier stayed valid after sign-out. The
// stored refresh token is now read before the teardown and sent.

import 'dart:async';

import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/network/interceptors/api_logging_interceptor.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';
import 'package:flutter_starter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/in_memory_stores.dart';

class _Remote implements AuthRemoteDataSource {
  _Remote({this.rejectLogout = false, this.logoutGate});

  final bool rejectLogout;
  final Completer<void>? logoutGate;
  String? sentRefreshToken;
  String? sentAccessToken;
  int logoutCalls = 0;

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
  Future<void> logout({String? refreshToken, String? accessToken}) async {
    logoutCalls++;
    sentRefreshToken = refreshToken;
    sentAccessToken = accessToken;
    await logoutGate?.future;
    // An expired access token: /auth/logout is excluded from the refresh.
    if (rejectLogout) throw const ServerException('expired', statusCode: 401);
  }

  @override
  Future<AuthResponseModel> refreshToken(String refreshToken) =>
      throw UnimplementedError();
}

void main() {
  for (final rejected in [false, true]) {
    test('logout sends the stored refresh token and tears down '
        '(server ${rejected ? 'answers 401' : 'accepts'})', () async {
      final tokens = InMemoryTokenStore()
        ..accessToken = 'access'
        ..refreshToken = 'the-refresh-token';
      final remote = _Remote(rejectLogout: rejected);
      final repository = AuthRepositoryImpl(
        remoteDataSource: remote,
        localDataSource: AuthLocalDataSourceImpl(
          storageService: InMemoryKeyValueStore(),
          tokenStore: tokens,
        ),
      );

      final result = await repository.logout();
      expect(result.isFailure, rejected);

      expect(remote.logoutCalls, 1);
      expect(remote.sentRefreshToken, 'the-refresh-token');
      expect(remote.sentAccessToken, 'access');
      expect(tokens.accessToken, isNull);
      expect(tokens.refreshToken, isNull);
    });
  }

  test(
    'a relaunch has no session while the remote logout is pending',
    () async {
      final tokens = InMemoryTokenStore()
        ..accessToken = 'access'
        ..refreshToken = 'the-refresh-token';
      final prefs = InMemoryKeyValueStore();
      final local = AuthLocalDataSourceImpl(
        storageService: prefs,
        tokenStore: tokens,
      );
      await local.cacheUser(
        const UserModel(id: 'a', email: 'a@example.com', name: 'A'),
      );
      final gate = Completer<void>();
      final remote = _Remote(logoutGate: gate);
      final repository = AuthRepositoryImpl(
        remoteDataSource: remote,
        localDataSource: local,
      );
      var completed = false;
      final logout = repository.logout().whenComplete(() => completed = true);
      try {
        await pumpEventQueue();
        expect(completed, isFalse);
        final relaunchedLocal = AuthLocalDataSourceImpl(
          storageService: prefs,
          tokenStore: tokens,
        );
        final relaunched = AuthRepositoryImpl(
          remoteDataSource: remote,
          localDataSource: relaunchedLocal,
        );
        expect(await relaunchedLocal.getToken(), isNull);
        expect(await relaunchedLocal.getRefreshToken(), isNull);
        expect(await relaunchedLocal.getCachedUser(), isNull);
        expect((await relaunched.getCurrentUser()).dataOrNull, isNull);
        expect(remote.sentRefreshToken, 'the-refresh-token');
        expect(remote.sentAccessToken, 'access');
        expect(remote.logoutCalls, 1);
      } finally {
        gate.complete();
        await logout;
      }
    },
  );

  test('the logout body field is redacted in logs', () {
    expect(ApiLoggingInterceptor.isSensitiveKey('refresh_token'), isTrue);
  });
}
