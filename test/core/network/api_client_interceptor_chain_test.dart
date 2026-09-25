// Drives the fully assembled ApiClient through a fake HttpClientAdapter to
// prove the interceptor chain actually reaches retry, 401 refresh and the
// performance trace teardown before ErrorInterceptor terminates it.
//
// Regression cover for koniz-dev/flutter-starter#46: ErrorInterceptor used to
// be registered FIRST, and because dio runs onError handlers in registration
// order, its handler.reject(...) terminated the chain before any of those ran.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/retry_interceptor.dart';
import 'package:flutter_starter/core/performance/i_performance_service.dart';
import 'package:flutter_starter/core/performance/performance_attributes.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorageService extends Mock implements StorageService {}

class _MockSecureStorageService extends Mock implements SecureStorageService {}

/// Adapter that counts every fetch and replies from a scripted queue.
///
/// The last scripted reply repeats once the queue is exhausted, so a test can
/// script "503 forever" with a single entry.
class _CountingAdapter implements HttpClientAdapter {
  _CountingAdapter(this._replies);

  final List<_Reply> _replies;

  /// Number of times the transport was actually hit.
  int hits = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final index = hits < _replies.length ? hits : _replies.length - 1;
    hits++;
    return _replies[index](options);
  }

  @override
  void close({bool force = false}) {}
}

/// A scripted transport reply, given the options dio is about to send.
typedef _Reply = ResponseBody Function(RequestOptions options);

_Reply _json(int statusCode, Map<String, dynamic> body) {
  return (_) => ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

/// Fails the transport with a real [DioException] of [type].
///
/// The exception carries the live [RequestOptions], so interceptors see the
/// actual method - dio rethrows an adapter-thrown DioException untouched
/// (`DioMixin.assureDioException`).
_Reply _fails(DioExceptionType type) {
  return (options) => throw DioException(requestOptions: options, type: type);
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

class _RecordingTrace implements IPerformanceTrace {
  bool started = false;
  bool stopped = false;
  final Map<String, String> attributes = {};
  final Map<String, int> metrics = {};

  @override
  String? getAttribute(String name) => attributes[name];

  @override
  int? getMetric(String metricName) => metrics[metricName];

  @override
  void incrementMetric(String metricName, int value) =>
      metrics[metricName] = (metrics[metricName] ?? 0) + value;

  @override
  void putAttribute(String name, String value) => attributes[name] = value;

  @override
  void putAttributes(Map<String, String> values) => attributes.addAll(values);

  @override
  void putMetric(String metricName, int value) => metrics[metricName] = value;

  @override
  Future<void> start() async => startSync();

  @override
  void startSync() => started = true;

  @override
  Future<void> stop() async => stopSync();

  @override
  void stopSync() => stopped = true;
}

class _RecordingPerformanceService implements IPerformanceService {
  final List<_RecordingTrace> traces = [];

  @override
  bool get isEnabled => true;

  @override
  IPerformanceTrace? startHttpTrace(String method, String path) {
    final trace = _RecordingTrace();
    traces.add(trace);
    return trace;
  }

  @override
  IPerformanceTrace? startScreenTrace(String screenName) =>
      startHttpTrace('SCREEN', screenName);

  @override
  IPerformanceTrace? startTrace(String name) => startHttpTrace('TRACE', name);

  @override
  Future<T> measureOperation<T>({
    required String name,
    required Future<T> Function() operation,
    Map<String, String>? attributes,
  }) => operation();

  @override
  T measureSyncComputation<T>({
    required String operationName,
    required T Function() computation,
    Map<String, String>? attributes,
  }) => computation();

  @override
  T measureSyncOperation<T>({
    required String name,
    required T Function() operation,
    Map<String, String>? attributes,
  }) => operation();
}

void main() {
  group('ApiClient interceptor chain', () {
    late _MockStorageService storageService;
    late _MockSecureStorageService secureStorageService;

    setUp(() {
      storageService = _MockStorageService();
      secureStorageService = _MockSecureStorageService();
    });

    // POST is used for the 401 and performance cases: CacheInterceptor only
    // touches GET, so the storage mock is never called and the chain under
    // test stays isolated.
    //
    // The retry case must use GET. Since #88, RetryInterceptor replays only
    // safe methods by default, so a POST would reach the transport once and
    // prove nothing about reachability. The GET path needs the cache lookup
    // stubbed to a miss (see below) but exercises the identical error chain.

    test(
      'retries a 503 through the assembled client (1 original + 3 retries) '
      'and still surfaces a domain ServerException',
      () async {
        // CacheInterceptor reads storage on GET; a miss lets the request out.
        when(
          () => storageService.getString(any()),
        ).thenAnswer((_) async => null);

        final adapter = _CountingAdapter([
          _json(503, {'message': 'Service unavailable'}),
        ]);
        final authInterceptor = AuthInterceptor(
          tokenStore: _InMemoryTokenStore(),
          refreshToken: () async => const Success('unused'),
        );
        final apiClient = ApiClient(
          storageService: storageService,
          secureStorageService: secureStorageService,
          authInterceptor: authInterceptor,
        )..dio.httpClientAdapter = adapter;

        Object? thrown;
        try {
          await apiClient.get('/tasks');
        } on Object catch (e) {
          thrown = e;
        }

        // Criterion 1 of #46: RetryInterceptor is reachable on the error path.
        expect(adapter.hits, 4);
        // Criterion 3 of #46: ErrorInterceptor still maps the exhausted
        // failure.
        expect(thrown, isA<ServerException>());
        expect((thrown! as ServerException).statusCode, 503);
        expect(thrown, isNot(isA<DioException>()));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'refreshes the token once on 401 and replays the original request',
      () async {
        final adapter = _CountingAdapter([
          _json(401, {'message': 'Unauthorized'}),
          _json(200, {'id': 'task-1'}),
        ]);
        final tokenStore = _InMemoryTokenStore();
        var refreshCalls = 0;
        final authInterceptor = AuthInterceptor(
          tokenStore: tokenStore,
          refreshToken: () async {
            refreshCalls++;
            return const Success('fresh-access-token');
          },
          // The replay deliberately uses a plain Dio so it cannot re-enter the
          // interceptor chain; point it at the same fake transport.
          retryDioFactory: () => Dio()..httpClientAdapter = adapter,
        );
        final apiClient = ApiClient(
          storageService: storageService,
          secureStorageService: secureStorageService,
          authInterceptor: authInterceptor,
        )..dio.httpClientAdapter = adapter;

        final response = await apiClient.post('/tasks', data: {'title': 'x'});

        // Criterion 2: refresh ran exactly once and the replay succeeded.
        expect(refreshCalls, 1);
        expect(adapter.hits, 2);
        expect(response.statusCode, 200);
        expect(response.data, {'id': 'task-1'});
        expect(tokenStore.accessToken, 'fresh-access-token');
      },
    );

    test('stops the performance trace when a request fails', () async {
      final adapter = _CountingAdapter([
        // 400 is not retryable, so this exercises the error path directly.
        _json(400, {'message': 'Bad request'}),
      ]);
      final performanceService = _RecordingPerformanceService();
      final authInterceptor = AuthInterceptor(
        tokenStore: _InMemoryTokenStore(),
        refreshToken: () async => const Success('unused'),
      );
      final apiClient = ApiClient(
        storageService: storageService,
        secureStorageService: secureStorageService,
        authInterceptor: authInterceptor,
        performanceService: performanceService,
      )..dio.httpClientAdapter = adapter;

      await expectLater(
        apiClient.post('/tasks', data: {'title': 'x'}),
        throwsA(isA<ServerException>()),
      );

      // Criterion 5: PerformanceInterceptor.onError ran.
      expect(performanceService.traces, hasLength(1));
      final trace = performanceService.traces.single;
      expect(trace.started, isTrue);
      expect(trace.stopped, isTrue);
      expect(trace.getMetric(PerformanceMetrics.error), 1);
      expect(trace.getAttribute(PerformanceAttributes.httpStatusCode), '400');
    });
  });

  // Regression cover for koniz-dev/flutter-starter#88: retry became reachable
  // for every method in #46, so a failing POST was replayed 4 times against a
  // degraded backend. Only safe methods are replayed now.
  group('ApiClient retry idempotency', () {
    late _MockStorageService storageService;
    late _MockSecureStorageService secureStorageService;

    setUp(() {
      storageService = _MockStorageService();
      secureStorageService = _MockSecureStorageService();
    });

    ApiClient buildClient(_CountingAdapter adapter) {
      return ApiClient(
        storageService: storageService,
        secureStorageService: secureStorageService,
        authInterceptor: AuthInterceptor(
          tokenStore: _InMemoryTokenStore(),
          refreshToken: () async => const Success('unused'),
        ),
      )..dio.httpClientAdapter = adapter;
    }

    test('a POST that fails with 503 reaches the transport once', () async {
      final adapter = _CountingAdapter([
        _json(503, {'message': 'Service unavailable'}),
      ]);
      final apiClient = buildClient(adapter);

      Object? thrown;
      try {
        await apiClient.post(
          '/auth/register',
          data: {'email': 'a@b.c', 'password': 'x'},
        );
      } on Object catch (e) {
        thrown = e;
      }

      expect(adapter.hits, 1);
      expect(thrown, isA<ServerException>());
      expect((thrown! as ServerException).statusCode, 503);
    });

    final nonReplayableFailures = <String, _Reply>{
      '503': _json(503, {'message': 'Service unavailable'}),
      '500': _json(500, {'message': 'Boom'}),
      'sendTimeout': _fails(DioExceptionType.sendTimeout),
      'receiveTimeout': _fails(DioExceptionType.receiveTimeout),
    };

    for (final method in ['POST', 'PUT', 'PATCH', 'DELETE']) {
      for (final failure in nonReplayableFailures.entries) {
        test(
          '$method failing with ${failure.key} reaches the transport once',
          () async {
            final adapter = _CountingAdapter([failure.value]);
            final apiClient = buildClient(adapter);

            await expectLater(
              apiClient.dio.request<dynamic>(
                '/orders',
                data: {'amount': 1},
                options: Options(method: method),
              ),
              throwsA(isA<DioException>()),
            );

            expect(
              adapter.hits,
              1,
              reason: '$method must not be replayed on ${failure.key}',
            );
          },
        );
      }
    }

    test(
      'a POST is still replayed on connectionTimeout, which proves the '
      'request never reached the server',
      () async {
        final adapter = _CountingAdapter([
          _fails(DioExceptionType.connectionTimeout),
        ]);
        final apiClient = buildClient(adapter);

        await expectLater(
          apiClient.post('/auth/register', data: {'email': 'a@b.c'}),
          throwsA(isA<NetworkException>()),
        );

        expect(adapter.hits, 4);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'an Idempotency-Key header opts a POST back into retry through the '
      'ApiClient facade',
      () async {
        final adapter = _CountingAdapter([
          _json(503, {'message': 'Service unavailable'}),
        ]);
        final apiClient = buildClient(adapter);

        await expectLater(
          apiClient.post(
            '/orders',
            data: {'amount': 1},
            headers: {RetryInterceptor.idempotencyKeyHeader: 'key-1'},
          ),
          throwsA(isA<ServerException>()),
        );

        expect(adapter.hits, 4);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
