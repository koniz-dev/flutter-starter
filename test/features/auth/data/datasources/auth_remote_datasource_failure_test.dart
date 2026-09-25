// Pins the failure type every AuthRemoteDataSource method surfaces, driven
// through a fully assembled ApiClient against a fake transport rather than a
// mocked ApiClient.
//
// Criterion 4 of koniz-dev/flutter-starter#176: the transport boundary stopped
// returning `dio.Response` and started returning `NetworkResponse`, so the
// failure path had to be pinned to a type that does not depend on which of the
// two the datasource holds. `auth_remote_datasource_test.dart` stubs
// `ApiClient` and therefore only ever proves what the stub was told to throw;
// this file drives the real interceptor chain, so what it asserts is what an
// adopter actually catches.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorageService extends Mock implements StorageService {}

class _MockSecureStorageService extends Mock implements SecureStorageService {}

/// Replies to every request with the same scripted status and body.
class _FixedAdapter implements HttpClientAdapter {
  _FixedAdapter(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;

  /// Number of times the transport was hit.
  int hits = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    hits++;
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _InMemoryTokenStore implements ITokenStore {
  String? _accessToken = 'access-token';
  String? _refreshToken = 'refresh-token';

  @override
  Future<void> clearAccessToken() async => _accessToken = null;

  @override
  Future<void> clearAllTokens() async {
    _accessToken = null;
    _refreshToken = null;
  }

  @override
  Future<void> clearRefreshToken() async => _refreshToken = null;

  @override
  Future<String?> getAccessToken() async => _accessToken;

  @override
  Future<String?> getRefreshToken() async => _refreshToken;

  @override
  Future<bool> setAccessToken(String token) async {
    _accessToken = token;
    return true;
  }

  @override
  Future<bool> setRefreshToken(String token) async {
    _refreshToken = token;
    return true;
  }
}

void main() {
  group('AuthRemoteDataSourceImpl failure behaviour (#176)', () {
    late _MockStorageService storageService;
    late _MockSecureStorageService secureStorageService;
    late _FixedAdapter adapter;
    late AuthRemoteDataSourceImpl dataSource;

    setUp(() {
      storageService = _MockStorageService();
      secureStorageService = _MockSecureStorageService();
      // 400 is neither retryable nor a refresh trigger, so exactly one
      // transport hit produces exactly one mapped exception.
      adapter = _FixedAdapter(400, {'message': 'Bad request'});
      final apiClient = ApiClient(
        storageService: storageService,
        secureStorageService: secureStorageService,
        authInterceptor: AuthInterceptor(
          tokenStore: _InMemoryTokenStore(),
          refreshToken: () async => const Success('unused'),
        ),
      )..dio.httpClientAdapter = adapter;
      dataSource = AuthRemoteDataSourceImpl(apiClient);
    });

    final calls = <String, Future<void> Function()>{
      'login': () => dataSource.login('a@b.c', 'password'),
      'register': () => dataSource.register('a@b.c', 'password', 'Name'),
      'logout': () => dataSource.logout(),
      'refreshToken': () => dataSource.refreshToken('refresh-token'),
    };

    for (final entry in calls.entries) {
      test('${entry.key} surfaces a ServerException on a 400', () async {
        Object? thrown;
        try {
          await entry.value();
        } on Object catch (e) {
          thrown = e;
        }

        expect(adapter.hits, 1);
        expect(thrown, isA<ServerException>());
        expect((thrown! as ServerException).statusCode, 400);
        // No dio type escapes the transport boundary.
        expect(thrown, isNot(isA<DioException>()));
      });
    }
  });
}
