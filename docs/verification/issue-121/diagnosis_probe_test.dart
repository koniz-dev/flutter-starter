// Diagnosis probe for koniz-dev/flutter-starter#121. NOT a committed test.
//
// Question: when `three concurrent 401s with a failing refresh` reports
// `refreshCalls` Expected: <1> Actual: <3>, is that
//   (a) the test releasing the held refresh before the other two 401s reach
//       AuthInterceptor.onError, or
//   (b) a hole in AuthInterceptor's `_isRefreshing` single-flight guard?
//
// The probe removes wall-clock time from the experiment entirely. It rendezvous
// structurally on the transport having served all three 401s, then grants a
// fixed number of event-loop turns before releasing the refresh, and reports
// how many refreshes the guard admitted. Turn count is ordering, not duration:
// a loaded machine runs the same continuations in the same order.
//
// Printing the measurements is this probe's entire output contract - the
// printed table is the artifact, so `avoid_print` does not apply to it.
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

class _ScriptedAdapter implements HttpClientAdapter {
  int hits = 0;
  final Map<int, Completer<void>> _marks = {};

  Future<void> served(int n) {
    if (hits >= n) return Future<void>.value();
    return (_marks[n] ??= Completer<void>()).future;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    hits++;
    final mark = _marks[hits];
    if (mark != null && !mark.isCompleted) mark.complete();
    return ResponseBody.fromString(
      jsonEncode({'message': 'Unauthorized'}),
      401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Store implements ITokenStore {
  String? accessToken = 'expired-access-token';
  String? refreshToken = 'refresh-token';
  int setAccessTokenCalls = 0;

  @override
  Future<void> clearAccessToken() async => accessToken = null;
  @override
  Future<void> clearAllTokens() async {
    accessToken = null;
    refreshToken = null;
  }

  @override
  Future<void> clearRefreshToken() async => refreshToken = null;
  @override
  Future<String?> getAccessToken() async => accessToken;
  @override
  Future<String?> getRefreshToken() async => refreshToken;
  @override
  Future<bool> setAccessToken(String token) async {
    setAccessTokenCalls++;
    accessToken = token;
    return true;
  }

  @override
  Future<bool> setRefreshToken(String token) async {
    refreshToken = token;
    return true;
  }
}

Future<Object?> _settle(Future<Response<dynamic>> f) async {
  try {
    await f;
    return null;
  } on Object catch (e) {
    return e;
  }
}

/// Runs one trial. [turns] event-loop turns are granted after the transport has
/// served all three 401s, before the held refresh is released. [turns] < 0
/// means "do not rendezvous at all": release as soon as the two later requests
/// have merely been *issued* - the shape of the old 50ms sleep when the sleep
/// loses its race.
Future<Map<String, int>> _trial(int turns) async {
  final adapter = _ScriptedAdapter();
  final store = _Store();
  final refreshStarted = Completer<void>();
  final release = Completer<void>();
  var refreshCalls = 0;

  final interceptor = AuthInterceptor(
    tokenStore: store,
    refreshToken: () async {
      refreshCalls++;
      if (!refreshStarted.isCompleted) refreshStarted.complete();
      await release.future;
      return const ResultFailure<String>(AuthFailure('Refresh token expired'));
    },
    retryDioFactory: () => Dio()..httpClientAdapter = _ScriptedAdapter(),
  );
  final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
    ..httpClientAdapter = adapter
    ..interceptors.add(interceptor);

  final first = _settle(dio.get<dynamic>('/profile'));
  await refreshStarted.future.timeout(const Duration(seconds: 5));
  final second = _settle(dio.get<dynamic>('/tasks'));
  final third = _settle(dio.get<dynamic>('/settings'));

  if (turns >= 0) {
    await adapter.served(3).timeout(const Duration(seconds: 5));
    for (var i = 0; i < turns; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }
  final atRelease = refreshCalls;
  release.complete();

  final outcomes = await Future.wait([
    first,
    second,
    third,
  ]).timeout(const Duration(seconds: 5));

  return {
    'turns': turns,
    'refreshCallsAtRelease': atRelease,
    'refreshCallsFinal': refreshCalls,
    'adapterHits': adapter.hits,
    'setAccessTokenCalls': store.setAccessTokenCalls,
    'errors': outcomes.whereType<DioException>().length,
  };
}

/// Counting subclass, identical to the one the fixed test now uses: it makes
/// "the guard has processed N 401s" observable instead of guessed at.
class _CountingAuthInterceptor extends AuthInterceptor {
  _CountingAuthInterceptor({
    required super.refreshToken,
    super.tokenStore,
    super.retryDioFactory,
  });

  int errorsSeen = 0;
  final Map<int, Completer<void>> _marks = {};

  Future<void> seen(int count) {
    if (errorsSeen >= count) return Future<void>.value();
    return (_marks[count] ??= Completer<void>()).future;
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) {
    final handled = super.onError(err, handler);
    errorsSeen++;
    final mark = _marks[errorsSeen];
    if (mark != null && !mark.isCompleted) mark.complete();
    return handled;
  }
}

/// [concurrency] simultaneous 401s, all inside one refresh window that is held
/// open. Returns the refreshes admitted and the token writes attempted while
/// the window was open - the two things a real single-flight hole would show.
Future<Map<String, int>> _stress(int concurrency) async {
  final adapter = _ScriptedAdapter();
  final store = _Store();
  final refreshStarted = Completer<void>();
  final release = Completer<void>();
  var refreshCalls = 0;

  final interceptor = _CountingAuthInterceptor(
    tokenStore: store,
    refreshToken: () async {
      refreshCalls++;
      if (!refreshStarted.isCompleted) refreshStarted.complete();
      await release.future;
      return const Success<String>('fresh-access-token');
    },
    retryDioFactory: () => Dio()..httpClientAdapter = _ScriptedAdapter(),
  );
  final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
    ..httpClientAdapter = adapter
    ..interceptors.add(interceptor);

  final pending = <Future<Object?>>[_settle(dio.get<dynamic>('/r0'))];
  await refreshStarted.future.timeout(const Duration(seconds: 10));
  for (var i = 1; i < concurrency; i++) {
    pending.add(_settle(dio.get<dynamic>('/r$i')));
  }
  await interceptor.seen(concurrency).timeout(const Duration(seconds: 10));

  final admitted = refreshCalls;
  final writes = store.setAccessTokenCalls;
  release.complete();
  await Future.wait(pending).timeout(const Duration(seconds: 10));

  return {
    'refreshesAdmittedInWindow': admitted,
    'tokenWritesInWindow': writes,
    'refreshesTotal': refreshCalls,
  };
}

void main() {
  test(
    'stress: N concurrent 401s inside one held-open refresh window',
    () async {
      final admitted = <int>{};
      final writes = <int>{};
      for (var i = 0; i < 200; i++) {
        final r = await _stress(10);
        admitted.add(r['refreshesAdmittedInWindow']!);
        writes.add(r['tokenWritesInWindow']!);
      }
      print(
        '200 trials x 10 concurrent 401s -> '
        'distinct refreshesAdmittedInWindow=$admitted '
        'distinct tokenWritesInWindow=$writes',
      );
      expect(admitted, {1});
      expect(writes, {0});
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'sweep: turns granted before releasing the refresh',
    () async {
      print('--- sweep ---');
      for (final turns in [-1, 0, 1, 2, 3, 4, 5, 6, 8, 12, 16, 32, 64]) {
        final r = await _trial(turns);
        print(
          'turns=${r['turns']!.toString().padLeft(3)} '
          'refreshCallsAtRelease=${r['refreshCallsAtRelease']} '
          'refreshCallsFinal=${r['refreshCallsFinal']} '
          'adapterHits=${r['adapterHits']} '
          'setAccessTokenCalls=${r['setAccessTokenCalls']} '
          'errors=${r['errors']}',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'repeat: 200 trials at 32 turns, guard must admit exactly one',
    () async {
      final observed = <int>{};
      for (var i = 0; i < 200; i++) {
        final r = await _trial(32);
        observed.add(r['refreshCallsAtRelease']!);
      }
      print(
        '200 trials at turns=32 -> distinct refreshCallsAtRelease=$observed',
      );
      expect(observed, {1});
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
