// Logout posted no body, so the server could not tell which refresh token to
// revoke, and an expired access token made the call 401 (/auth/logout is not
// refreshed). A refresh token copied earlier stayed valid after sign-out. The
// stored refresh token is now read before the teardown and sent.

import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/network/interceptors/api_logging_interceptor.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/in_memory_stores.dart';

class _Remote implements AuthRemoteDataSource {
  _Remote({this.rejectLogout = false});

  final bool rejectLogout;
  String? sentRefreshToken;
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
  Future<void> logout({String? refreshToken}) async {
    logoutCalls++;
    sentRefreshToken = refreshToken;
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

      await repository.logout();

      expect(remote.logoutCalls, 1);
      expect(remote.sentRefreshToken, 'the-refresh-token');
      expect(tokens.accessToken, isNull);
      expect(tokens.refreshToken, isNull);
    });
  }

  test('the logout body field is redacted in logs', () {
    expect(ApiLoggingInterceptor.isSensitiveKey('refresh_token'), isTrue);
  });
}
