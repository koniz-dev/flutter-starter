// Assembled-ApiClient variant: a session-A GET answered 401 after A signed out
// and B signed in is refreshed with B's refresh token and replayed as B.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/session/session_generation.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/in_memory_stores.dart';

class _MockStorage extends Mock implements StorageService {}

class _MockSecure extends Mock implements SecureStorageService {}

class _Adapter implements HttpClientAdapter {
  final List<String> wire = [];
  final Completer<void> releaseFirst = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    final auth = o.headers['Authorization'];
    wire.add('${o.method} ${o.path} $auth');
    if (wire.length == 1) {
      await releaseFirst.future;
      return ResponseBody.fromString('{}', 401, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });
    }
    return ResponseBody.fromString(jsonEncode({'profile_of': auth}), 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('session-A request is not replayed with session-B credentials', () async {
    final store = InMemoryTokenStore()
      ..accessToken = 'A-access'
      ..refreshToken = 'A-refresh';
    final generation = SessionGeneration();
    final refreshedWith = <String?>[];
    final interceptor = AuthInterceptor(
      tokenStore: store,
      sessionGeneration: generation,
      refreshToken: () async {
        refreshedWith.add(store.refreshToken);
        await store.setRefreshToken('B-refresh-2');
        return const Success('B-access-2');
      },
    );
    final adapter = _Adapter();
    final client = ApiClient(
      storageService: _MockStorage(),
      secureStorageService: _MockSecure(),
      authInterceptor: interceptor,
      retryInitialDelay: Duration.zero,
      retryMaxJitter: Duration.zero,
    )..dio.httpClientAdapter = adapter;

    final pending = client.get('/me');
    await pumpEventQueue();

    // Logout (A), then login (B): both advance the generation.
    generation.invalidate();
    await store.clearAllTokens();
    generation.invalidate();
    store
      ..accessToken = 'B-access'
      ..refreshToken = 'B-refresh';

    adapter.releaseFirst.complete();
    Object? outcome;
    try {
      outcome = (await pending).data;
    } on Object catch (e) {
      outcome = e;
    }
    print('wire=${adapter.wire}');
    print('refreshedWith=$refreshedWith outcome=$outcome');
    expect(refreshedWith, isEmpty);
    expect(adapter.wire, hasLength(1));
  });
}
