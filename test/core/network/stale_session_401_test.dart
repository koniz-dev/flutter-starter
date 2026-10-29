// A 401 belongs to the session its request was sent under. When that session
// has ended by the time the 401 arrives - its user signed out, and maybe
// someone else signed in - the 401 must not refresh the *current* user's
// tokens, replay the old request as them, or tear the current session down.
//
// Every test drives the assembled ApiClient, so the Cache, Auth, Retry and
// Error interceptors are all in the chain.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/contracts/state_boundary_contracts.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/session/session_generation.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/in_memory_stores.dart';

class _MockStorageService extends Mock implements StorageService {}

class _MockSecureStorageService extends Mock implements SecureStorageService {}

class _CountingSink implements ISessionTerminationSink {
  int calls = 0;

  @override
  void onSessionTerminated() => calls++;
}

/// Answers by path. A path listed in [held] waits for its completer before
/// answering its first hit; [status] gives each path's status (default 200).
class _Adapter implements HttpClientAdapter {
  _Adapter({this.held = const {}, this.status = const {}});

  final Map<String, Completer<void>> held;
  final Map<String, int> status;
  final List<String> wire = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    final firstHit = !wire.any((w) => w.startsWith('$path '));
    wire.add('$path ${options.headers['Authorization']}');
    final gate = held[path];
    if (firstHit && gate != null) await gate.future;
    final code = firstHit ? (status[path] ?? 200) : 200;
    return ResponseBody.fromString(
      jsonEncode({'answered_with': options.headers['Authorization']}),
      code,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late InMemoryTokenStore store;
  late SessionGeneration generation;
  late _CountingSink sink;
  late List<String?> refreshedWith;
  late Completer<void>? refreshGate;

  ApiClient build(_Adapter adapter) {
    return ApiClient(
      storageService: _MockStorageService(),
      secureStorageService: _MockSecureStorageService(),
      authInterceptor: AuthInterceptor(
        tokenStore: store,
        sessionGeneration: generation,
        sessionSink: sink,
        refreshToken: () async {
          refreshedWith.add(store.refreshToken);
          await refreshGate?.future;
          return Success('${store.refreshToken}-new-access');
        },
      ),
      retryInitialDelay: Duration.zero,
      retryMaxJitter: Duration.zero,
    )..dio.httpClientAdapter = adapter;
  }

  /// The app's sign-out: the generation moves first, then storage empties.
  Future<void> signOut() async {
    generation.invalidate();
    await store.clearAllTokens();
  }

  /// The app's sign-in: a new generation, then the new user's tokens.
  void signIn(String user) {
    generation.invalidate();
    store
      ..accessToken = '$user-access'
      ..refreshToken = '$user-refresh';
  }

  Future<Object?> outcomeOf(Future<Object?> request) async {
    try {
      return await request;
    } on Object catch (e) {
      return e;
    }
  }

  setUp(() {
    store = InMemoryTokenStore()
      ..accessToken = 'A-access'
      ..refreshToken = 'A-refresh';
    generation = SessionGeneration();
    sink = _CountingSink();
    refreshedWith = [];
    refreshGate = null;
  });

  test("an ended session's 401 does not refresh the next user's tokens or "
      'replay the request as them', () async {
    final gate = Completer<void>();
    final adapter = _Adapter(held: {'/v1/me': gate}, status: {'/v1/me': 401});
    final client = build(adapter);

    final pending = outcomeOf(client.get('/me'));
    await pumpEventQueue();
    await signOut();
    signIn('B');
    gate.complete();

    final outcome = await pending;

    expect(refreshedWith, isEmpty);
    expect(adapter.wire, ['/v1/me Bearer A-access']);
    expect(outcome, isA<Exception>());
    expect(store.accessToken, 'B-access');
    expect(store.refreshToken, 'B-refresh');
  });

  test("an ended session's 401 is not queued behind, or replayed by, a "
      'refresh the newer session started', () async {
    final aGate = Completer<void>();
    final adapter = _Adapter(
      held: {'/v1/a': aGate},
      status: {'/v1/a': 401, '/v1/b': 401},
    );
    final client = build(adapter);

    final a = outcomeOf(client.get('/a'));
    await pumpEventQueue();
    await signOut();
    signIn('B');

    // B's own 401 starts a refresh that stays in flight...
    refreshGate = Completer<void>();
    final b = outcomeOf(client.get('/b'));
    await pumpEventQueue();
    expect(refreshedWith, ['B-refresh']);

    // ...and A's stale 401 lands while it is.
    aGate.complete();
    final aOutcome = await a;
    refreshGate!.complete();
    final bOutcome = await b;

    expect(aOutcome, isA<Exception>());
    expect(refreshedWith, ['B-refresh'], reason: 'one refresh, for B only');
    expect(
      adapter.wire.where((w) => w.startsWith('/v1/a ')),
      ['/v1/a Bearer A-access'],
      reason: "A's request is never replayed with B's token",
    );
    expect(bOutcome, isNot(isA<Exception>()));
    expect(adapter.wire.last, '/v1/b Bearer B-refresh-new-access');
  });

  test("an ended session's 401 with nothing stored does not end the session "
      'again', () async {
    final gate = Completer<void>();
    final adapter = _Adapter(held: {'/v1/me': gate}, status: {'/v1/me': 401});
    final client = build(adapter);

    final pending = outcomeOf(client.get('/me'));
    await pumpEventQueue();
    await signOut();
    final afterSignOut = generation.current;
    gate.complete();

    expect(await pending, isA<Exception>());
    expect(refreshedWith, isEmpty);
    expect(sink.calls, 0);
    expect(generation.current, afterSignOut);
  });

  test('a 401 within one session still refreshes once and replays', () async {
    final adapter = _Adapter(status: {'/v1/me': 401});
    final client = build(adapter);

    final outcome = await outcomeOf(client.get('/me'));

    expect(outcome, isNot(isA<Exception>()));
    expect(refreshedWith, ['A-refresh']);
    expect(adapter.wire, [
      '/v1/me Bearer A-access',
      '/v1/me Bearer A-refresh-new-access',
    ]);
  });
}
