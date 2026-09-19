// Regression cover for koniz-dev/flutter-starter#59.
//
// Drives AuthInterceptor through a real Dio against a fake HttpClientAdapter,
// so every assertion is about futures the caller actually awaits - the queued
// handlers used to be neither resolved nor rejected, which no mock-handler
// test can observe. No test in this file touches the network.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adapter that replies from a scripted queue and counts every fetch.
///
/// The last scripted reply repeats once the queue is exhausted.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._replies);

  final List<ResponseBody Function()> _replies;

  int hits = 0;
  bool closed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final index = hits < _replies.length ? hits : _replies.length - 1;
    hits++;
    return _replies[index]();
  }

  @override
  void close({bool force = false}) => closed = true;
}

ResponseBody Function() _json(int statusCode, Map<String, dynamic> body) {
  return () => ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _InMemoryTokenStore implements ITokenStore {
  String? accessToken = 'expired-access-token';
  String? refreshToken = 'refresh-token';

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
    accessToken = token;
    return true;
  }

  @override
  Future<bool> setRefreshToken(String token) async {
    refreshToken = token;
    return true;
  }
}

/// Awaits [future] and returns the error it threw, or null on success.
Future<Object?> _settle(Future<Response<dynamic>> future) async {
  try {
    await future;
    return null;
  } on Object catch (error) {
    return error;
  }
}

/// A future that must not outlive [seconds]; a hang fails the test instead of
/// stalling the whole suite.
Future<T> _within<T>(Future<T> future, {int seconds = 5}) {
  return future.timeout(Duration(seconds: seconds));
}

void main() {
  group('AuthInterceptor 401 refresh queue', () {
    late _ScriptedAdapter mainAdapter;
    late _ScriptedAdapter retryAdapter;
    late _InMemoryTokenStore tokenStore;

    setUp(() {
      // Every request 401s unless a test scripts otherwise.
      mainAdapter = _ScriptedAdapter([
        _json(401, {'message': 'Unauthorized'}),
      ]);
      retryAdapter = _ScriptedAdapter([
        _json(200, {'replayed': true}),
      ]);
      tokenStore = _InMemoryTokenStore();
    });

    /// Builds a Dio wired to [interceptor] and the fake main transport.
    Dio clientFor(AuthInterceptor interceptor) {
      return Dio(BaseOptions(baseUrl: 'https://example.invalid'))
        ..httpClientAdapter = mainAdapter
        ..interceptors.add(interceptor);
    }

    test(
      'three concurrent 401s with a failing refresh: all three complete',
      () async {
        final refreshStarted = Completer<void>();
        final releaseRefresh = Completer<void>();
        var refreshCalls = 0;
        var retryDiosBuilt = 0;

        final interceptor = AuthInterceptor(
          tokenStore: tokenStore,
          refreshToken: () async {
            refreshCalls++;
            if (!refreshStarted.isCompleted) {
              refreshStarted.complete();
            }
            await releaseRefresh.future;
            return const ResultFailure<String>(
              AuthFailure('Refresh token expired'),
            );
          },
          retryDioFactory: () {
            retryDiosBuilt++;
            return Dio()..httpClientAdapter = retryAdapter;
          },
        );
        final dio = clientFor(interceptor);

        // First request starts the refresh...
        final first = _settle(dio.get<dynamic>('/profile'));
        await _within(refreshStarted.future);
        // ...the other two land while it is in flight and are queued.
        final second = _settle(dio.get<dynamic>('/tasks'));
        final third = _settle(dio.get<dynamic>('/settings'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        releaseRefresh.complete();

        final outcomes = await _within(Future.wait([first, second, third]));

        // Criterion 1: nobody is left awaiting a future that never completes.
        expect(outcomes, hasLength(3));
        expect(outcomes.whereType<DioException>(), hasLength(3));
        // The refresh ran once; the other two were queued, not re-refreshed.
        expect(refreshCalls, 1);
        // Refresh failed, so nothing was replayed and the user was logged out.
        expect(retryAdapter.hits, 0);
        expect(retryDiosBuilt, 0);
        expect(tokenStore.accessToken, isNull);
        expect(tokenStore.refreshToken, isNull);
      },
    );

    test(
      'three concurrent 401s with a succeeding refresh: all three replay '
      'through a single retry client',
      () async {
        final refreshStarted = Completer<void>();
        final releaseRefresh = Completer<void>();
        var refreshCalls = 0;
        var retryDiosBuilt = 0;

        final interceptor = AuthInterceptor(
          tokenStore: tokenStore,
          refreshToken: () async {
            refreshCalls++;
            if (!refreshStarted.isCompleted) {
              refreshStarted.complete();
            }
            await releaseRefresh.future;
            return const Success<String>('fresh-access-token');
          },
          retryDioFactory: () {
            retryDiosBuilt++;
            return Dio()..httpClientAdapter = retryAdapter;
          },
        );
        final dio = clientFor(interceptor);

        final first = _settle(dio.get<dynamic>('/profile'));
        await _within(refreshStarted.future);
        final second = _settle(dio.get<dynamic>('/tasks'));
        final third = _settle(dio.get<dynamic>('/settings'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        releaseRefresh.complete();

        final outcomes = await _within(Future.wait([first, second, third]));

        // Criterion 1: all three resolved, none stranded.
        expect(outcomes, everyElement(isNull));
        expect(refreshCalls, 1);
        expect(retryAdapter.hits, 3);
        // Criterion 4: one replay client for all three replays, not one each.
        expect(retryDiosBuilt, 1);
        expect(tokenStore.accessToken, 'fresh-access-token');
      },
    );

    test(
      'an Error thrown by the refresh does not wedge the interceptor',
      () async {
        var refreshCalls = 0;

        final interceptor = AuthInterceptor(
          tokenStore: tokenStore,
          refreshToken: () async {
            refreshCalls++;
            // An Error, not an Exception: the old `on Exception` catch missed
            // it, left _isRefreshing true and queued every later 401 forever.
            throw StateError('malformed refresh response');
          },
          retryDioFactory: () => Dio()..httpClientAdapter = retryAdapter,
        );
        final dio = clientFor(interceptor);

        final firstError = await _within(_settle(dio.get<dynamic>('/profile')));
        expect(firstError, isA<DioException>());
        expect((firstError! as DioException).error, isA<StateError>());

        // Criterion 2: the next 401 still completes rather than hanging.
        final secondError = await _within(_settle(dio.get<dynamic>('/tasks')));
        expect(secondError, isA<DioException>());
        expect(refreshCalls, 2);
      },
    );

    test('reuses one retry client and closes it on dispose', () async {
      var retryDiosBuilt = 0;
      final interceptor = AuthInterceptor(
        tokenStore: tokenStore,
        refreshToken: () async => const Success<String>('fresh-access-token'),
        retryDioFactory: () {
          retryDiosBuilt++;
          return Dio()..httpClientAdapter = retryAdapter;
        },
      );
      final dio = clientFor(interceptor);

      await _within(_settle(dio.get<dynamic>('/profile')));
      await _within(_settle(dio.get<dynamic>('/tasks')));

      // Criterion 4: one client across multiple 401 storms.
      expect(retryDiosBuilt, 1);
      expect(identical(interceptor.retryDio(), interceptor.retryDio()), isTrue);
      expect(retryAdapter.closed, isFalse);

      interceptor.dispose();

      // Criterion 4: the transport is released, not leaked.
      expect(retryAdapter.closed, isTrue);
    });

    test('cancelling the original request aborts the replay', () async {
      final refreshStarted = Completer<void>();
      final releaseRefresh = Completer<void>();
      final cancelToken = CancelToken();

      final interceptor = AuthInterceptor(
        tokenStore: tokenStore,
        refreshToken: () async {
          if (!refreshStarted.isCompleted) {
            refreshStarted.complete();
          }
          await releaseRefresh.future;
          return const Success<String>('fresh-access-token');
        },
        retryDioFactory: () => Dio()..httpClientAdapter = retryAdapter,
      );
      final dio = clientFor(interceptor);

      final outcome = _settle(
        dio.get<dynamic>('/profile', cancelToken: cancelToken),
      );
      await _within(refreshStarted.future);
      cancelToken.cancel('user left the screen');
      releaseRefresh.complete();

      final error = await _within(outcome);

      // Criterion 5: the cancel token reached the replay, which never ran.
      expect(error, isA<DioException>());
      expect((error! as DioException).type, DioExceptionType.cancel);
      expect(retryAdapter.hits, 0);
    });

    test(
      'propagates the original cancel token to the replay request',
      () async {
        final cancelToken = CancelToken();
        final interceptor = AuthInterceptor(
          tokenStore: tokenStore,
          refreshToken: () async => const Success<String>('fresh-access-token'),
          retryDioFactory: () => Dio()
            ..httpClientAdapter = retryAdapter
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest: (options, handler) {
                  // Criterion 5: same token instance, so a later cancel still
                  // aborts the in-flight replay.
                  expect(identical(options.cancelToken, cancelToken), isTrue);
                  handler.next(options);
                },
              ),
            ),
        );
        final dio = clientFor(interceptor);

        final error = await _within(
          _settle(dio.get<dynamic>('/profile', cancelToken: cancelToken)),
        );

        expect(error, isNull);
        expect(retryAdapter.hits, 1);
      },
    );
  });
}
