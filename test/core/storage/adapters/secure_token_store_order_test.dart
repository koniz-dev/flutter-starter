// flutter_secure_storage on web awaits WebCrypto encryption before a write
// reaches localStorage, but removes a key at once. So a logout's clear, issued
// after a token refresh had checked the session and started writing, ran
// before that write landed - and the write then put a live access token back
// on a signed-out browser. SecureTokenStore now applies its operations in the
// order they are issued. These run it over a storage that reorders like the
// web plugin.

import 'dart:async';

import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/storage/adapters/secure_token_store.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_starter/features/auth/domain/auth_error_codes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/in_memory_stores.dart';

class _MockSecureStorage extends Mock implements SecureStorageService {}

/// A secure storage whose writes land after an asynchronous step (the web
/// plugin's encryption) and whose deletes land at once.
class _WebLikeStorage {
  _WebLikeStorage() {
    when(() => mock.getStringOrThrow(any())).thenAnswer(
      (i) async => values[i.positionalArguments[0] as String],
    );
    when(() => mock.setString(any(), any())).thenAnswer((i) async {
      final key = i.positionalArguments[0] as String;
      final value = i.positionalArguments[1] as String;
      writeStarted.remove(key)?.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      values[key] = value;
      return true;
    });
    when(() => mock.remove(any())).thenAnswer((i) async {
      values.remove(i.positionalArguments[0] as String);
      return true;
    });
  }

  final mock = _MockSecureStorage();
  final Map<String, String> values = {};

  /// Completes when a write to the key starts.
  final Map<String, Completer<void>> writeStarted = {};

  Future<void> whenWriteStarts(String key) =>
      (writeStarted[key] = Completer<void>()).future;
}

class _Remote implements AuthRemoteDataSource {
  static AuthResponseModel _pair(String prefix) => AuthResponseModel.fromJson({
    'user': {'id': '42', 'email': 'a@b.c'},
    'token': '$prefix-access',
    'refresh_token': '$prefix-refresh',
  });

  @override
  Future<AuthResponseModel> login(String email, String password) async =>
      _pair('login');

  @override
  Future<AuthResponseModel> register(
    String email,
    String password,
    String name,
  ) => throw UnimplementedError();

  /// Offline: the remote logout fails at once, so the local clear follows
  /// immediately.
  @override
  Future<void> logout() async => throw Exception('offline');

  @override
  Future<AuthResponseModel> refreshToken(String refreshToken) async =>
      _pair('new');
}

void main() {
  late _WebLikeStorage storage;
  late SecureTokenStore tokens;
  late AuthRepositoryImpl repository;

  setUp(() {
    storage = _WebLikeStorage()
      ..values[AppConstants.tokenKey] = 'old-access'
      ..values[AppConstants.refreshTokenKey] = 'old-refresh';
    tokens = SecureTokenStore(storage.mock);
    repository = AuthRepositoryImpl(
      remoteDataSource: _Remote(),
      localDataSource: AuthLocalDataSourceImpl(
        storageService: InMemoryKeyValueStore(),
        tokenStore: tokens,
      ),
    );
  });

  void expectStale(Result<String> result) {
    expect(
      (result as ResultFailure<String>).failure,
      isA<Failure>().having(
        (f) => f.code,
        'code',
        AuthErrorCodes.sessionTerminated,
      ),
    );
  }

  test('a clear issued after a pending write lands after it', () async {
    final write = tokens.setAccessToken('late');
    final clear = tokens.clearAllTokens();
    await (write, clear).wait;

    expect(storage.values[AppConstants.tokenKey], isNull);
    expect(storage.values[AppConstants.refreshTokenKey], isNull);
  });

  test('a logout during the refresh write leaves no token behind', () async {
    final started = storage.whenWriteStarts(AppConstants.tokenKey);
    final refresh = repository.refreshToken();
    await started;
    final logout = repository.logout();

    final (result, _) = await (refresh, logout).wait;

    expect(await tokens.getAccessToken(), isNull);
    expect(await tokens.getRefreshToken(), isNull);
    expectStale(result);
  });

  test('a login completing after the stale refresh write keeps its own '
      'tokens', () async {
    final started = storage.whenWriteStarts(AppConstants.tokenKey);
    final refresh = repository.refreshToken();
    await started;
    final login = repository.login('a@b.c', 'pw');

    final (result, signedIn) = await (refresh, login).wait;

    expect(signedIn, isA<Success<Object?>>());
    expect(await tokens.getAccessToken(), 'login-access');
    expect(await tokens.getRefreshToken(), 'login-refresh');
    expectStale(result);
  });
}
