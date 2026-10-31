// AuthInterceptor's forced logout (a 401 that cannot be refreshed) clears the
// tokens and the cached user after invalidating the session. A sign-in that
// started after the invalidate and completed before the clear landed - a
// slow keychain - reported success, and the clear then deleted its
// credentials. A sign-in now waits for that teardown, as it does for a
// user's logout.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/contracts/state_boundary_contracts.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/session/session_generation.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_starter/features/auth/domain/auth_error_codes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/in_memory_stores.dart';

class _MockSecureStorageService extends Mock implements SecureStorageService {}

/// A token store whose clear waits for [releaseClear], as a slow keychain
/// would.
class _SlowClearStore extends InMemoryTokenStore {
  final Completer<void> releaseClear = Completer<void>();

  @override
  Future<void> clearAllTokens() async {
    await releaseClear.future;
    await super.clearAllTokens();
  }
}

/// A key-value store whose remove never completes, as a stuck platform call.
class _HungRemoveStore extends InMemoryKeyValueStore {
  @override
  Future<bool> remove(String key) => Completer<bool>().future;
}

class _Sink implements ISessionTerminationSink {
  int calls = 0;

  @override
  void onSessionTerminated() => calls++;
}

/// 401 for every request.
class _Unauthorized implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({'error': 'expired'}),
    401,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

/// Sign-ins wait for the next completer in [replies].
class _Remote implements AuthRemoteDataSource {
  final List<Completer<AuthResponseModel>> replies = [];

  @override
  Future<AuthResponseModel> login(String email, String password) {
    final reply = Completer<AuthResponseModel>();
    replies.add(reply);
    return reply.future;
  }

  @override
  Future<AuthResponseModel> register(
    String email,
    String password,
    String name,
  ) => throw UnimplementedError();

  @override
  Future<void> logout({String? refreshToken}) async {}

  @override
  Future<AuthResponseModel> refreshToken(String refreshToken) =>
      throw UnimplementedError();
}

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('a sign-in during a forced logout waits for its teardown and keeps '
      'its credentials', () async {
    final generation = SessionGeneration();
    final tokens = _SlowClearStore()..accessToken = 'old-access';
    final storage = InMemoryKeyValueStore();
    final sink = _Sink();
    final apiClient = ApiClient(
      storageService: InMemoryStorage(),
      secureStorageService: _MockSecureStorageService(),
      authInterceptor: AuthInterceptor(
        tokenStore: tokens,
        keyValueStore: storage,
        sessionSink: sink,
        sessionGeneration: generation,
        // No refresh token: the 401 ends the session.
        refreshToken: () async => const ResultFailure(
          UnknownFailure(
            'No refresh token available',
            code: AuthErrorCodes.refreshTokenExpired,
          ),
        ),
      ),
    )..dio.httpClientAdapter = _Unauthorized();
    final remote = _Remote();
    final repository = AuthRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: AuthLocalDataSourceImpl(
        storageService: storage,
        tokenStore: tokens,
      ),
      sessionGeneration: generation,
    );

    // The forced logout starts; its clear is held.
    final request = apiClient
        .get('/me')
        .then<void>(
          (_) {},
          onError: (Object _) {},
        );
    await _settle();

    final signIn = repository.login('a@b.c', 'pw');
    await _settle();
    expect(remote.replies, isEmpty, reason: 'it waits for the teardown');

    tokens.releaseClear.complete();
    await request;
    await _settle();
    expect(sink.calls, 1);
    remote.replies.single.complete(
      AuthResponseModel.fromJson({
        'user': {'id': 'a', 'email': 'a@b.c'},
        'token': 'a-access',
        'refresh_token': 'a-refresh',
      }),
    );

    expect(await signIn, isA<Success<Object?>>());
    expect(tokens.accessToken, 'a-access');
    expect(tokens.refreshToken, 'a-refresh');
    expect((await repository.getCurrentUser()).dataOrNull, isNotNull);
  });

  test('a forced-logout step that never completes is bounded, so a later '
      'sign-in succeeds', () async {
    final generation = SessionGeneration();
    final tokens = InMemoryTokenStore()..accessToken = 'old-access';
    final sink = _Sink();
    final apiClient = ApiClient(
      storageService: InMemoryStorage(),
      secureStorageService: _MockSecureStorageService(),
      authInterceptor: AuthInterceptor(
        tokenStore: tokens,
        keyValueStore: _HungRemoveStore(),
        sessionSink: sink,
        sessionGeneration: generation,
        teardownStepTimeout: const Duration(milliseconds: 20),
        refreshToken: () async => const ResultFailure(
          UnknownFailure(
            'No refresh token available',
            code: AuthErrorCodes.refreshTokenExpired,
          ),
        ),
      ),
    )..dio.httpClientAdapter = _Unauthorized();
    final remote = _Remote();
    final repository = AuthRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: AuthLocalDataSourceImpl(
        storageService: InMemoryKeyValueStore(),
        tokenStore: tokens,
      ),
      sessionGeneration: generation,
      pendingLogoutLimit: const Duration(seconds: 5),
    );

    await apiClient.get('/me').then<void>((_) {}, onError: (Object _) {});
    expect(sink.calls, 1, reason: 'the teardown ran past the hung step');

    final signIn = repository.login('a@b.c', 'pw');
    await _settle();
    remote.replies.single.complete(
      AuthResponseModel.fromJson({
        'user': {'id': 'a', 'email': 'a@b.c'},
        'token': 'a-access',
        'refresh_token': 'a-refresh',
      }),
    );
    expect(await signIn, isA<Success<Object?>>());
  });
}
