// A token store whose getAccessToken throws an AppException - a custom
// ITokenStore raising CacheException, say - fails the request it was reading
// for, carrying that exception. When that request is the token refresh, the
// refresh fails with a CacheFailure, and the session ends: the same outcome as
// a store that cannot read the refresh token, and the fail-closed rule for
// any refresh failure that is not transport trouble.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/contracts/state_boundary_contracts.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/in_memory_stores.dart';

class _MockSecureStorageService extends Mock implements SecureStorageService {}

/// Reads the access token normally until [failReads] is set.
class _FailingStore extends InMemoryTokenStore {
  bool failReads = false;

  @override
  Future<String?> getAccessToken() async {
    if (failReads) throw const CacheException('keystore unavailable');
    return accessToken;
  }
}

class _CountingSink implements ISessionTerminationSink {
  int calls = 0;

  @override
  void onSessionTerminated() => calls++;
}

/// 401 for every request; [onFetch] runs first, with the request's path.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.onFetch);

  final void Function(String path) onFetch;
  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    onFetch(options.path);
    return ResponseBody.fromString(
      jsonEncode({'error': 'expired'}),
      401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _FailingStore tokens;
  late _CountingSink sink;

  setUp(() {
    tokens = _FailingStore()
      ..accessToken = 'access'
      ..refreshToken = 'refresh';
    sink = _CountingSink();
  });

  ApiClient client(_Adapter adapter) {
    late final AuthRepositoryImpl repository;
    final apiClient = ApiClient(
      storageService: InMemoryStorage(),
      secureStorageService: _MockSecureStorageService(),
      authInterceptor: AuthInterceptor(
        tokenStore: tokens,
        sessionSink: sink,
        refreshToken: () => repository.refreshToken(),
      ),
    )..dio.httpClientAdapter = adapter;
    repository = AuthRepositoryImpl(
      remoteDataSource: AuthRemoteDataSourceImpl(apiClient),
      localDataSource: AuthLocalDataSourceImpl(
        storageService: InMemoryKeyValueStore(),
        tokenStore: tokens,
      ),
    );
    return apiClient;
  }

  test('a failed read on an ordinary request fails it and keeps the '
      'session', () async {
    tokens.failReads = true;
    final adapter = _Adapter((_) {});

    await expectLater(
      client(adapter).get('/me'),
      throwsA(isA<CacheException>()),
    );

    expect(adapter.paths, isEmpty, reason: 'nothing was sent');
    expect(sink.calls, 0);
    expect(tokens.refreshToken, 'refresh');
  });

  test('a failed read on the refresh call ends the session', () async {
    // The 401 starts a refresh; the refresh call's token read then fails.
    final adapter = _Adapter((_) => tokens.failReads = true);

    await expectLater(
      client(adapter).get('/me'),
      throwsA(
        isA<ServerException>().having((e) => e.statusCode, 'status', 401),
      ),
      reason: 'the caller gets the original 401',
    );

    expect(adapter.paths, ['/me'], reason: 'the refresh call was not sent');
    expect(sink.calls, 1, reason: 'the running app was told');
    expect(tokens.accessToken, isNull);
    expect(tokens.refreshToken, isNull);
  });
}
