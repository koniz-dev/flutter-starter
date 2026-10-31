// A token refresh whose body the app cannot parse - an int user id, a missing
// token - made the generated fromJson throw a TypeError. refreshToken()
// caught only Exceptions, so the Error escaped its Result contract and
// AuthNotifier.refreshToken() threw. It now fails with INVALID_AUTH_RESPONSE,
// and AuthInterceptor ends the session for it: a body that cannot be read
// will not read better on the next attempt.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/contracts/state_boundary_contracts.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';
import 'package:flutter_starter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_starter/features/auth/domain/usecases/refresh_token_usecase.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/in_memory_stores.dart';

class _MockSecureStorageService extends Mock implements SecureStorageService {}

class _Remote implements AuthRemoteDataSource {
  _Remote(this.body);

  final Map<String, dynamic> body;

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
  Future<void> logout({String? refreshToken}) async {}

  @override
  Future<AuthResponseModel> refreshToken(String refreshToken) async =>
      AuthResponseModel.fromJson(body);
}

class _CountingSink implements ISessionTerminationSink {
  int calls = 0;

  @override
  void onSessionTerminated() => calls++;
}

class _Always401 implements HttpClientAdapter {
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

const _unreadableBodies = <String, Map<String, dynamic>>{
  'an int user id': {
    'user': {'id': 42, 'email': 'a@b.c'},
    'token': 'tok',
  },
  'no token': {
    'user': {'id': '42', 'email': 'a@b.c'},
  },
};

void main() {
  late InMemoryTokenStore tokens;

  AuthRepositoryImpl repo(Map<String, dynamic> body) => AuthRepositoryImpl(
    remoteDataSource: _Remote(body),
    localDataSource: AuthLocalDataSourceImpl(
      storageService: InMemoryKeyValueStore(),
      tokenStore: tokens,
    ),
  );

  setUp(() {
    tokens = InMemoryTokenStore()
      ..accessToken = 'old-access'
      ..refreshToken = 'old-refresh';
  });

  _unreadableBodies.forEach((label, body) {
    test('criterion 1 ($label): refreshToken returns INVALID_AUTH_RESPONSE '
        'and writes no token', () async {
      final result = await repo(body).refreshToken();

      expect(result, isA<ResultFailure<String>>());
      expect(result.failureOrNull?.code, 'INVALID_AUTH_RESPONSE');
      expect(tokens.accessToken, 'old-access');
      expect(tokens.refreshToken, 'old-refresh');
    });

    test('criterion 2 ($label): AuthNotifier.refreshToken completes without '
        'throwing', () async {
      final container = ProviderContainer(
        overrides: [
          refreshTokenUseCaseProvider.overrideWithValue(
            RefreshTokenUseCase(repo(body)),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(authNotifierProvider.notifier).refreshToken(),
        completes,
      );
    });
  });

  test(
    'criterion 3: AuthInterceptor ends the session for that failure',
    () async {
      final sink = _CountingSink();
      final client = ApiClient(
        storageService: InMemoryStorage(),
        secureStorageService: _MockSecureStorageService(),
        authInterceptor: AuthInterceptor(
          tokenStore: tokens,
          sessionSink: sink,
          refreshToken: () =>
              repo(_unreadableBodies.values.first).refreshToken(),
        ),
      )..dio.httpClientAdapter = _Always401();

      await expectLater(client.get('/me'), throwsA(anything));

      expect(sink.calls, 1, reason: 'the running app was told');
      expect(tokens.accessToken, isNull);
      expect(tokens.refreshToken, isNull);
    },
  );
}
