// refreshToken() checked the session once, after the round trip, and then
// wrote the access token and the refresh token with an await between them.
// A logout landing while the first write was in flight cleared the store, and
// the refresh token was then written after the clear: a signed-out device kept
// a live refresh token, and the refresh reported Success. The session is now
// checked again immediately before each write and before returning.

import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_starter/features/auth/domain/auth_error_codes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/in_memory_stores.dart';

class _Remote implements AuthRemoteDataSource {
  @override
  Future<AuthResponseModel> login(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<AuthResponseModel> register(
    String email,
    String password,
    String name,
  ) => throw UnimplementedError();

  /// Offline: the remote logout fails at once, so the local teardown runs
  /// while the refresh's first write is still pending.
  @override
  Future<void> logout() async => throw Exception('offline');

  @override
  Future<AuthResponseModel> refreshToken(String refreshToken) async =>
      AuthResponseModel.fromJson({
        'user': {'id': '42', 'email': 'a@b.c'},
        'token': 'new-access',
        'refresh_token': 'new-refresh',
      });
}

/// Runs [onAccessWrite] once the access token has landed, and holds the write
/// open until it completes - as a platform write that has reached the store
/// but not yet returned to the caller.
class _Store extends InMemoryTokenStore {
  Future<void> Function()? onAccessWrite;

  @override
  Future<bool> setAccessToken(String token) async {
    accessToken = token;
    final hook = onAccessWrite;
    onAccessWrite = null;
    if (hook != null) await hook();
    return true;
  }
}

void main() {
  test('a logout during the access-token write leaves no token behind and '
      'fails the refresh', () async {
    final tokens = _Store()
      ..accessToken = 'old-access'
      ..refreshToken = 'old-refresh';
    final repository = AuthRepositoryImpl(
      remoteDataSource: _Remote(),
      localDataSource: AuthLocalDataSourceImpl(
        storageService: InMemoryKeyValueStore(),
        tokenStore: tokens,
      ),
    );
    tokens.onAccessWrite = () async {
      await repository.logout();
    };

    final result = await repository.refreshToken();

    expect(tokens.refreshToken, isNull, reason: 'signed out, so nothing left');
    expect(tokens.accessToken, isNull);
    expect(result, isA<ResultFailure<String>>());
    expect(
      (result as ResultFailure<String>).failure,
      isA<Failure>().having(
        (f) => f.code,
        'code',
        AuthErrorCodes.sessionTerminated,
      ),
    );
  });
}
