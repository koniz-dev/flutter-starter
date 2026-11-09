import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/contracts/state_boundary_contracts.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/in_memory_stores.dart';

class _Secure extends Mock implements SecureStorageService {}

class _Sink implements ISessionTerminationSink {
  @override
  void onSessionTerminated() {}
}

class _Server implements HttpClientAdapter {
  _Server(this.tokens);

  final InMemoryTokenStore tokens;
  Object? bearer;
  Object? body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // The request may still authenticate, but disk must already be signed out.
    expect(tokens.accessToken, isNull);
    expect(tokens.refreshToken, isNull);
    bearer = options.headers['Authorization'];
    body = options.data;
    return ResponseBody.fromString(
      jsonEncode({'ok': bearer == 'Bearer old-access'}),
      bearer == 'Bearer old-access' ? 200 : 401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('revocation keeps its captured bearer after local teardown', () async {
    final tokens = InMemoryTokenStore()
      ..accessToken = 'old-access'
      ..refreshToken = 'old-refresh';
    final prefs = InMemoryKeyValueStore();
    final server = _Server(tokens);
    final client = ApiClient(
      storageService: InMemoryStorage(),
      secureStorageService: _Secure(),
      authInterceptor: AuthInterceptor(
        refreshToken: () async => const Success('unused'),
        tokenStore: tokens,
        keyValueStore: prefs,
        sessionSink: _Sink(),
      ),
    );
    client.dio.httpClientAdapter = server;
    addTearDown(() => client.dio.close(force: true));
    final repository = AuthRepositoryImpl(
      remoteDataSource: AuthRemoteDataSourceImpl(client),
      localDataSource: AuthLocalDataSourceImpl(
        storageService: prefs,
        tokenStore: tokens,
      ),
    );

    final result = await repository.logout();

    expect(server.bearer, 'Bearer old-access');
    expect(server.body, {'refresh_token': 'old-refresh'});
    expect(result.isSuccess, isTrue);
    expect(tokens.accessToken, isNull);
    expect(tokens.refreshToken, isNull);
  });
}
