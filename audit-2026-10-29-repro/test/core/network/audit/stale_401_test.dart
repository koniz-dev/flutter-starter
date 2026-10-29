// A request issued under session A that comes back 401 after A ended and B
// signed in must not refresh B's credentials nor be replayed as B.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/session/session_generation.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/in_memory_stores.dart';

class _HeldAdapter implements HttpClientAdapter {
  final List<RequestOptions> sent = [];
  final Completer<void> releaseFirst = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sent.add(options);
    if (sent.length == 1) {
      await releaseFirst.future;
      return ResponseBody.fromString('{}', 401, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });
    }
    final who = options.headers['Authorization'];
    return ResponseBody.fromString(jsonEncode({'owner': who}), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('stale 401 from an ended session is not refreshed or replayed', () async {
    final store = InMemoryTokenStore()
      ..accessToken = 'A-access'
      ..refreshToken = 'A-refresh';
    final generation = SessionGeneration();
    final adapter = _HeldAdapter();
    var refreshCalls = 0;
    final interceptor = AuthInterceptor(
      tokenStore: store,
      sessionGeneration: generation,
      refreshToken: () async {
        refreshCalls++;
        return const Success('B-access-refreshed');
      },
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter
      ..interceptors.add(interceptor);
    interceptor.attachTransport(dio);

    // User A asks for their profile.
    final pending = dio.get<dynamic>('/me');
    await pumpEventQueue();
    expect(adapter.sent.single.headers['Authorization'], 'Bearer A-access');

    // A signs out, B signs in (logout and login each advance the generation).
    generation.invalidate();
    store.accessToken = null;
    store.refreshToken = null;
    generation.invalidate();
    store.accessToken = 'B-access';
    store.refreshToken = 'B-refresh';

    // A's request now comes back 401 (A's token was revoked on logout).
    adapter.releaseFirst.complete();
    Object? outcome;
    try {
      outcome = (await pending).data;
    } on DioException catch (e) {
      outcome = e;
    }

    print('refreshCalls=$refreshCalls sent=${adapter.sent.map((o) => o.headers['Authorization']).toList()} outcome=$outcome');
    expect(refreshCalls, 0, reason: "A's 401 rotated B's tokens");
    expect(outcome, isA<DioException>(),
        reason: "A's caller received a response fetched with B's token");
  });
}
