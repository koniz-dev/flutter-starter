// Drives the fully assembled ApiClient through a fake HttpClientAdapter to
// prove the interceptor chain actually reaches retry, 401 refresh and the
// performance trace teardown before ErrorInterceptor terminates it.
//
// Regression cover for koniz-dev/flutter-starter#46: ErrorInterceptor used to
// be registered FIRST, and because dio runs onError handlers in registration
// order, its handler.reject(...) terminated the chain before any of those ran.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/network/interceptors/retry_interceptor.dart';
import 'package:flutter_starter/core/performance/i_performance_service.dart';
import 'package:flutter_starter/core/performance/performance_attributes.dart';
import 'package:flutter_starter/core/session/session_generation.dart';
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

/// Token store whose `setAccessToken` blocks until [release] completes.
///
/// [writeStarted] completes when the write begins, so a test can act inside
/// the window between the refresh succeeding and the token being stored.
class _GatedTokenStore extends _InMemoryTokenStore {
  final Completer<void> writeStarted = Completer<void>();
  final Completer<void> release = Completer<void>();

  @override
  Future<bool> setAccessToken(String token) async {
    if (!writeStarted.isCompleted) writeStarted.complete();
    await release.future;
    return super.setAccessToken(token);
  }
}

/// Token store that switches the session to user B during one specific read.
///
/// Only reads made by `AuthInterceptor.onRequest` count - `CacheInterceptor`
/// reads the same store first. The caller is identified from the synchronous
/// stack, which still holds `onRequest`'s frame when the read starts. On the
/// [switchOnAuthRead]-th such read the shared generation is advanced (what
/// `logout()` and `login()` do first) and user B's token is returned, as if
/// the switch had landed while the platform read was in flight.
class _SessionSwitchingTokenStore extends _InMemoryTokenStore {
  _SessionSwitchingTokenStore(this._generation, this.switchOnAuthRead) {
    accessToken = 'USER-A';
  }

  final SessionGeneration _generation;
  final int switchOnAuthRead;

  /// Reads made by `AuthInterceptor.onRequest` so far.
  int authReads = 0;

  @override
  Future<String?> getAccessToken() async {
    if (StackTrace.current.toString().contains('AuthInterceptor.onRequest')) {
      authReads++;
      if (authReads == switchOnAuthRead) {
        _generation.invalidate();
        accessToken = 'USER-B';
      }
    }
    return accessToken;
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

/// A [LoggingService] that records every `error` call and prints nothing.
class _RecordingLoggingService extends LoggingService {
  _RecordingLoggingService() : super(enableLogging: false);

  final List<String> errors = [];

  @override
  void error(
    String message, {
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  }) => errors.add(message);
}

/// An [AuthInterceptor] that announces when its 401 handling has processed a
/// given number of errors.
///
/// Same structural rendezvous as the one in
/// `interceptors/auth_interceptor_refresh_queue_test.dart`: `super.onError`
/// starts the refresh or queues the request before its first `await`, so
/// awaiting [seen] means "N 401s have been parked", not "N ms have passed".
class _CountingAuthInterceptor extends AuthInterceptor {
  _CountingAuthInterceptor({required super.refreshToken, super.tokenStore});

  int errorsSeen = 0;

  final Map<int, Completer<void>> _marks = {};

  Future<void> seen(int count) {
    if (errorsSeen >= count) {
      return Future<void>.value();
    }
    return (_marks[count] ??= Completer<void>()).future;
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) {
    final handled = super.onError(err, handler);
    errorsSeen++;
    final mark = _marks[errorsSeen];
    if (mark != null && !mark.isCompleted) {
      mark.complete();
    }
    return handled;
  }
}

/// Matches the domain exception a 401 must surface as: the same
/// [ServerException] `ErrorInterceptor` produces for any other failing
/// status, carrying the server's message - never a `NetworkException` and
/// never `Instance of 'NetworkError'`.
final Matcher _isMapped401 = isA<ServerException>()
    .having((e) => e.statusCode, 'statusCode', 401)
    .having((e) => e.message, 'message', 'Unauthorized')
    .having((e) => e.code, 'code', 'TOKEN_EXPIRED');

/// Awaits [future] and returns what it threw, or null.
Future<Object?> _thrownBy(Future<Object?> future) async {
  try {
    await future;
    return null;
  } on Object catch (e) {
    return e;
  }
}

/// What a re-send refused because its session ended reaches the caller as.
final Matcher _isEndedSessionCancel = isA<NetworkException>().having(
  (e) => e.code,
  'code',
  'REQUEST_CANCELLED',
);

const ResultFailure<String> _refreshRejected = ResultFailure<String>(
  AuthFailure('Refresh token expired', code: 'REFRESH_TOKEN_EXPIRED'),
);

/// Transport that records every request it receives and replies from a script.
///
/// Each script entry is either an HTTP status (int) or a [DioExceptionType] to
/// throw. The last entry repeats once the script is exhausted. [onHit] runs
/// before the reply, with the 1-based hit number.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this._script, {this.onHit});

  final List<Object> _script;
  final Future<void> Function(int hit)? onHit;

  /// The `Authorization` header of every request that reached the transport.
  final List<String?> authorizations = [];

  int get hits => authorizations.length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    authorizations.add(options.headers['Authorization'] as String?);
    await onHit?.call(hits);
    final step =
        _script[hits <= _script.length ? hits - 1 : _script.length - 1];
    if (step is DioExceptionType) {
      throw DioException(requestOptions: options, type: step);
    }
    return ResponseBody.fromString(
      jsonEncode({'hit': hits}),
      step as int,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
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

  // koniz-dev/flutter-starter#298: a 401 that was refreshed and replayed
  // successfully was traced as a failed 401. PerformanceInterceptor used to
  // run first and stop the trace in its onError before AuthInterceptor
  // recovered, and the replay's 200 is resolved from onError, which ends the
  // host chain. The real replay client is used here (no retryDioFactory), so
  // the replay borrows the host transport and its PerformanceInterceptor.
  group('the performance trace of a refreshed request (#298)', () {
    late _MockStorageService storageService;
    late _MockSecureStorageService secureStorageService;
    late _RecordingPerformanceService performance;

    setUp(() {
      storageService = _MockStorageService();
      secureStorageService = _MockSecureStorageService();
      performance = _RecordingPerformanceService();
    });

    ApiClient clientWith(
      AuthInterceptor authInterceptor,
      _RecordingAdapter adapter,
    ) => ApiClient(
      storageService: storageService,
      secureStorageService: secureStorageService,
      authInterceptor: authInterceptor,
      performanceService: performance,
    )..dio.httpClientAdapter = adapter;

    void expectSucceeded(_RecordingTrace trace) {
      expect(trace.started, isTrue);
      expect(trace.stopped, isTrue);
      expect(trace.getMetric(PerformanceMetrics.success), 1);
      expect(trace.getMetric(PerformanceMetrics.error), isNull);
      expect(trace.getAttribute(PerformanceAttributes.httpStatusCode), '200');
    }

    test('criterion 1: [401, 200] with a successful refresh ends as a 200 '
        'success, and no trace records a failure', () async {
      final adapter = _RecordingAdapter([401, 200]);
      final client = clientWith(
        AuthInterceptor(
          tokenStore: _InMemoryTokenStore(),
          refreshToken: () async => const Success('fresh-access-token'),
        ),
        adapter,
      );

      final response = await client.post('/tasks', data: {'title': 'x'});

      expect(response.statusCode, 200);
      expect(adapter.hits, 2);
      expect(performance.traces, hasLength(1));
      expectSucceeded(performance.traces.single);
    });

    test('criterion 2: a request queued behind the in-flight refresh and '
        'drained also ends as a 200 success', () async {
      final release = Completer<void>();
      final adapter = _RecordingAdapter([401, 401, 200]);
      final auth = _CountingAuthInterceptor(
        tokenStore: _InMemoryTokenStore(),
        refreshToken: () async {
          await release.future;
          return const Success('fresh-access-token');
        },
      );
      final client = clientWith(auth, adapter);

      final first = client.post('/tasks', data: {'title': 'a'});
      final second = client.post('/tasks', data: {'title': 'b'});
      // Structural: both 401s are parked, the second one queued.
      await auth.seen(2);
      release.complete();

      final responses = await Future.wait([first, second]);

      expect(responses.map((r) => r.statusCode), [200, 200]);
      expect(performance.traces, hasLength(2));
      performance.traces.forEach(expectSucceeded);
    });

    test('criterion 3: a 401 whose refresh fails is still traced as a 401 '
        'error', () async {
      final adapter = _RecordingAdapter([401]);
      final client = clientWith(
        AuthInterceptor(
          tokenStore: _InMemoryTokenStore(),
          refreshToken: () async => _refreshRejected,
        ),
        adapter,
      );

      await expectLater(
        client.post('/tasks', data: {'title': 'x'}),
        throwsA(isA<ServerException>()),
      );

      expect(performance.traces, hasLength(1));
      final trace = performance.traces.single;
      expect(trace.stopped, isTrue);
      expect(trace.getMetric(PerformanceMetrics.error), 1);
      expect(trace.getMetric(PerformanceMetrics.success), isNull);
      expect(trace.getAttribute(PerformanceAttributes.httpStatusCode), '401');
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

  // koniz-dev/flutter-starter#276. AuthInterceptor used to end the error chain
  // whenever it gave up on a 401, so ErrorInterceptor never mapped it and the
  // caller got NetworkException("Instance of 'NetworkError'"). Every exit
  // below is one of the paths that used to do that.
  group(
    'a 401 AuthInterceptor gives up on is mapped like any other status',
    () {
      late _MockStorageService storageService;
      late _MockSecureStorageService secureStorageService;
      late _InMemoryTokenStore tokenStore;

      setUp(() {
        storageService = _MockStorageService();
        secureStorageService = _MockSecureStorageService();
        tokenStore = _InMemoryTokenStore();
        // A forced logout empties the response cache, which walks its index.
        when(
          () => storageService.getStringList(any()),
        ).thenAnswer((_) async => null);
        when(() => storageService.remove(any())).thenAnswer((_) async => true);
      });

      _Reply unauthorized() => _json(401, {
        'message': 'Unauthorized',
        'code': 'TOKEN_EXPIRED',
      });

      ApiClient buildClient(
        AuthInterceptor authInterceptor,
        _CountingAdapter adapter, {
        LoggingService? loggingService,
      }) {
        return ApiClient(
          storageService: storageService,
          secureStorageService: secureStorageService,
          authInterceptor: authInterceptor,
          loggingService: loggingService,
        )..dio.httpClientAdapter = adapter;
      }

      test('criterion 1: a 401 whose refresh fails', () async {
        final adapter = _CountingAdapter([unauthorized()]);
        final apiClient = buildClient(
          AuthInterceptor(
            tokenStore: tokenStore,
            refreshToken: () async => _refreshRejected,
          ),
          adapter,
        );

        final thrown = await _thrownBy(
          apiClient.post('/tasks', data: {'title': 'x'}),
        );

        expect(thrown, _isMapped401);
        expect(thrown.toString(), isNot(contains('Instance of')));
        expect(adapter.hits, 1);
        // The forced logout itself still happened.
        expect(tokenStore.accessToken, isNull);
      });

      test(
        'criterion 2: the retry-exhausted branch (X-Retry-Count: 1)',
        () async {
          final adapter = _CountingAdapter([unauthorized()]);
          var refreshCalls = 0;
          final apiClient = buildClient(
            AuthInterceptor(
              tokenStore: tokenStore,
              refreshToken: () async {
                refreshCalls++;
                return const Success('unused');
              },
            ),
            adapter,
          );

          final thrown = await _thrownBy(
            apiClient.post(
              '/tasks',
              data: {'title': 'x'},
              headers: {'X-Retry-Count': '1'},
            ),
          );

          expect(thrown, _isMapped401);
          expect(
            refreshCalls,
            0,
            reason: 'this branch logs out without a refresh',
          );
        },
      );

      test(
        'criterion 2: the stale-generation branch (session ended mid-refresh)',
        () async {
          final adapter = _CountingAdapter([unauthorized()]);
          final generation = SessionGeneration();
          final apiClient = buildClient(
            AuthInterceptor(
              tokenStore: tokenStore,
              sessionGeneration: generation,
              refreshToken: () async {
                // A logout lands while the refresh is in flight.
                generation.invalidate();
                return const Success('fresh-access-token');
              },
            ),
            adapter,
          );

          final thrown = await _thrownBy(
            apiClient.post('/tasks', data: {'title': 'x'}),
          );

          expect(thrown, _isMapped401);
          expect(adapter.hits, 1, reason: 'a stale refresh must not replay');
          expect(
            tokenStore.accessToken,
            isNot('fresh-access-token'),
            reason: 'a stale refresh must not persist its token',
          );
        },
      );

      test(
        'criterion 2: a request queued behind a refresh that then fails',
        () async {
          final adapter = _CountingAdapter([unauthorized()]);
          final refreshStarted = Completer<void>();
          final releaseRefresh = Completer<void>();
          final interceptor = _CountingAuthInterceptor(
            tokenStore: tokenStore,
            refreshToken: () async {
              refreshStarted.complete();
              await releaseRefresh.future;
              return _refreshRejected;
            },
          );
          final apiClient = buildClient(interceptor, adapter);

          final first = _thrownBy(apiClient.post('/tasks', data: {'n': 1}));
          await refreshStarted.future.timeout(const Duration(seconds: 5));
          final queued = _thrownBy(apiClient.post('/tasks', data: {'n': 2}));
          await interceptor.seen(2).timeout(const Duration(seconds: 5));
          releaseRefresh.complete();

          expect(await first, _isMapped401);
          expect(
            await queued,
            _isMapped401,
            reason:
                'the queued request is rejected by the drain, not the refresh',
          );
          expect(adapter.hits, 2);
        },
      );

      test(
        'criterion 3: the failed-refresh 401 is logged exactly once',
        () async {
          final adapter = _CountingAdapter([unauthorized()]);
          final logging = _RecordingLoggingService();
          final apiClient = buildClient(
            AuthInterceptor(
              tokenStore: tokenStore,
              refreshToken: () async => _refreshRejected,
            ),
            adapter,
            loggingService: logging,
          );

          await _thrownBy(apiClient.post('/tasks', data: {'title': 'x'}));

          expect(
            logging.errors.where((m) => m.startsWith('API Error')),
            hasLength(1),
          );
          expect(logging.errors.single, contains('/tasks'));
        },
      );
    },
  );

  // koniz-dev/flutter-starter#286. Once AuthInterceptor forwarded its failures
  // down the chain (#276), a replay that failed transiently after a successful
  // refresh reached RetryInterceptor, which re-sent it - carrying the bearer
  // token minted for the session the forced logout had just ended - and handed
  // the caller a success.
  group('nothing is sent after a forced logout', () {
    late _MockStorageService storageService;
    late _MockSecureStorageService secureStorageService;
    late _InMemoryTokenStore tokenStore;
    late SessionGeneration generation;

    setUp(() {
      storageService = _MockStorageService();
      secureStorageService = _MockSecureStorageService();
      tokenStore = _InMemoryTokenStore();
      generation = SessionGeneration();
      when(() => storageService.getString(any())).thenAnswer((_) async => null);
      // An anonymous 200 is cached once the token is gone.
      when(
        () => storageService.setString(any(), any()),
      ).thenAnswer((_) async => true);
      when(
        () => storageService.setStringList(any(), any()),
      ).thenAnswer((_) async => true);
      when(
        () => storageService.getStringList(any()),
      ).thenAnswer((_) async => null);
      when(() => storageService.remove(any())).thenAnswer((_) async => true);
    });

    ApiClient buildClient(_RecordingAdapter adapter) {
      return ApiClient(
        storageService: storageService,
        secureStorageService: secureStorageService,
        authInterceptor: AuthInterceptor(
          tokenStore: tokenStore,
          sessionGeneration: generation,
          refreshToken: () async => const Success('fresh-access-token'),
        ),
      )..dio.httpClientAdapter = adapter;
    }

    // Criterion 1 is the 503 case; criterion 3 adds the two transport
    // failures. Each replay failure is one RetryInterceptor treats as
    // transient for a GET, so before the fix every one of them was re-sent.
    //
    // Since koniz-dev/flutter-starter#304 a transient replay failure no
    // longer ends the session either: the refresh succeeded, so the fresh
    // token is kept and only this request fails. What #286 guards - nothing
    // re-sent after the replay - is unchanged.
    for (final replayFailure in <Object>[
      503,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
    ]) {
      test(
        'criteria 1-3: a replay failing with $replayFailure is not re-sent, '
        'and the session is kept',
        () async {
          final adapter = _RecordingAdapter([401, replayFailure, 200]);
          final apiClient = buildClient(adapter);
          final before = generation.current;

          final thrown = await _thrownBy(apiClient.get('/tasks'));

          expect(
            thrown,
            isA<AppException>(),
            reason: 'the caller must fail, not receive the re-sent response',
          );
          expect(
            adapter.hits,
            2,
            reason: 'original + replay only; the failed replay is not re-sent',
          );
          expect(adapter.authorizations, [
            'Bearer expired-access-token',
            'Bearer fresh-access-token',
          ]);
          // #304: a transient replay failure is not a dead session.
          expect(generation.isCurrent(before), isTrue);
          expect(tokenStore.accessToken, 'fresh-access-token');
        },
        timeout: const Timeout(Duration(minutes: 1)),
      );
    }

    test(
      'criterion 4: a retry made after the token is gone carries no '
      'Authorization header from the earlier attempt',
      () async {
        // 503 on a GET is retried. The session ends between the first attempt
        // and the retry - the logout lands during the backoff.
        final adapter = _RecordingAdapter(
          [503, 200],
          onHit: (hit) async {
            if (hit == 1) await tokenStore.clearAllTokens();
          },
        );
        final apiClient = buildClient(adapter);

        await apiClient.get('/public/feed');

        expect(adapter.hits, 2);
        expect(adapter.authorizations.first, 'Bearer expired-access-token');
        expect(
          adapter.authorizations.last,
          isNull,
          reason: 'the header the first attempt carried must be removed',
        );
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );

    test(
      'criterion 4: an Authorization header the caller attached is kept',
      () async {
        tokenStore.accessToken = null;
        final adapter = _RecordingAdapter([200]);
        final apiClient = buildClient(adapter);

        await apiClient.get(
          '/partner/feed',
          headers: {'Authorization': 'Basic caller-supplied'},
        );

        expect(adapter.authorizations, ['Basic caller-supplied']);
      },
    );
  });

  group('a retry is never sent under a different session', () {
    late _MockStorageService storageService;
    late _MockSecureStorageService secureStorageService;
    late _InMemoryTokenStore tokenStore;
    late SessionGeneration generation;

    setUp(() {
      storageService = _MockStorageService();
      secureStorageService = _MockSecureStorageService();
      tokenStore = _InMemoryTokenStore()..accessToken = 'USER-A';
      generation = SessionGeneration();
      when(() => storageService.getString(any())).thenAnswer((_) async => null);
      when(
        () => storageService.setString(any(), any()),
      ).thenAnswer((_) async => true);
      when(
        () => storageService.setStringList(any(), any()),
      ).thenAnswer((_) async => true);
      when(
        () => storageService.getStringList(any()),
      ).thenAnswer((_) async => null);
      when(() => storageService.remove(any())).thenAnswer((_) async => true);
    });

    ApiClient buildClient(_RecordingAdapter adapter) {
      return ApiClient(
        storageService: storageService,
        secureStorageService: secureStorageService,
        authInterceptor: AuthInterceptor(
          tokenStore: tokenStore,
          sessionGeneration: generation,
          refreshToken: () async => const Success('unused'),
        ),
      )..dio.httpClientAdapter = adapter;
    }

    /// User A signs out and user B signs in while the first attempt is
    /// failing, i.e. before RetryInterceptor's backoff even starts.
    Future<void> switchToUserB(int hit) async {
      if (hit != 1) return;
      generation.invalidate();
      await tokenStore.clearAllTokens();
      tokenStore.accessToken = 'USER-B';
    }

    test(
      'criterion 1: a GET that failed under session A is not re-sent with '
      "session B's token",
      () async {
        final adapter = _RecordingAdapter([503, 200], onHit: switchToUserB);
        final apiClient = buildClient(adapter);

        final thrown = await _thrownBy(apiClient.get('/me'));

        expect(
          thrown,
          _isEndedSessionCancel,
          reason: "session A's caller must not receive session B's data",
        );
        expect(adapter.authorizations, ['Bearer USER-A']);
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );

    test(
      'criterion 2: a POST opted into replay with an Idempotency-Key is not '
      "re-sent with session B's token",
      () async {
        final adapter = _RecordingAdapter([503, 200], onHit: switchToUserB);
        final apiClient = buildClient(adapter);

        final thrown = await _thrownBy(
          apiClient.post(
            '/orders',
            data: {'sku': 'a-1'},
            headers: {RetryInterceptor.idempotencyKeyHeader: 'order-1'},
          ),
        );

        expect(
          thrown,
          _isEndedSessionCancel,
          reason: "a write session A started must not commit on B's account",
        );
        expect(adapter.authorizations, ['Bearer USER-A']);
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );

    test(
      'criterion 3: a retry within one session is still sent',
      () async {
        final adapter = _RecordingAdapter([503, 200]);
        final apiClient = buildClient(adapter);

        final response = await apiClient.get('/me');

        expect(response.statusCode, 200);
        expect(adapter.authorizations, ['Bearer USER-A', 'Bearer USER-A']);
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );
  });

  // koniz-dev/flutter-starter#290. The head request's replay - the one whose
  // 401 started the refresh - was the only replay that did not re-check the
  // session after `await setAccessToken`, so a logout landing during that
  // secure-storage write still put the fresh token on the wire.
  group(
    'the 401 head replay re-checks the session after storing the token',
    () {
      late _MockStorageService storageService;
      late _MockSecureStorageService secureStorageService;
      late _GatedTokenStore tokenStore;
      late SessionGeneration generation;

      setUp(() {
        storageService = _MockStorageService();
        secureStorageService = _MockSecureStorageService();
        tokenStore = _GatedTokenStore();
        generation = SessionGeneration();
        when(
          () => storageService.getString(any()),
        ).thenAnswer((_) async => null);
        when(
          () => storageService.setString(any(), any()),
        ).thenAnswer((_) async => true);
        when(
          () => storageService.setStringList(any(), any()),
        ).thenAnswer((_) async => true);
        when(
          () => storageService.getStringList(any()),
        ).thenAnswer((_) async => null);
        when(() => storageService.remove(any())).thenAnswer((_) async => true);
      });

      ApiClient buildClient(_RecordingAdapter adapter) {
        return ApiClient(
          storageService: storageService,
          secureStorageService: secureStorageService,
          authInterceptor: AuthInterceptor(
            tokenStore: tokenStore,
            sessionGeneration: generation,
            refreshToken: () async => const Success('fresh-access-token'),
          ),
        )..dio.httpClientAdapter = adapter;
      }

      test(
        'criterion 1: a logout during the token write stops the replay',
        () async {
          final adapter = _RecordingAdapter([401, 200]);
          final apiClient = buildClient(adapter);

          final call = _thrownBy(apiClient.get('/me'));
          await tokenStore.writeStarted.future;
          // What AuthRepositoryImpl.logout() does first, synchronously.
          generation.invalidate();
          tokenStore.release.complete();

          expect(
            await call,
            isA<AppException>(),
            reason: 'the caller of an ended session must fail, not succeed',
          );
          expect(
            adapter.authorizations,
            ['Bearer expired-access-token'],
            reason: 'the replay must never reach the transport',
          );
        },
        timeout: const Timeout(Duration(minutes: 1)),
      );

      test(
        'criterion 2: with no session change the replay carries the new token',
        () async {
          final adapter = _RecordingAdapter([401, 200]);
          final apiClient = buildClient(adapter);
          final before = generation.current;

          final call = apiClient.get('/me');
          await tokenStore.writeStarted.future;
          tokenStore.release.complete();
          final response = await call;

          expect(response.statusCode, 200);
          expect(adapter.authorizations, [
            'Bearer expired-access-token',
            'Bearer fresh-access-token',
          ]);
          expect(generation.isCurrent(before), isTrue);
          expect(tokenStore.accessToken, 'fresh-access-token');
        },
        timeout: const Timeout(Duration(minutes: 1)),
      );
    },
  );

  // koniz-dev/flutter-starter#295. onRequest checked the request's generation
  // before `await getAccessToken()` and not after it, so a session switch that
  // landed during that platform read still sent the request - first send or
  // re-send - with the new user's bearer token.
  group('a session switch during the token read stops the request', () {
    late _MockStorageService storageService;
    late _MockSecureStorageService secureStorageService;
    late SessionGeneration generation;

    setUp(() {
      storageService = _MockStorageService();
      secureStorageService = _MockSecureStorageService();
      generation = SessionGeneration();
      when(() => storageService.getString(any())).thenAnswer((_) async => null);
      when(
        () => storageService.setString(any(), any()),
      ).thenAnswer((_) async => true);
      when(
        () => storageService.setStringList(any(), any()),
      ).thenAnswer((_) async => true);
      when(
        () => storageService.getStringList(any()),
      ).thenAnswer((_) async => null);
      when(() => storageService.remove(any())).thenAnswer((_) async => true);
    });

    ApiClient buildClient(ITokenStore tokenStore, _RecordingAdapter adapter) {
      return ApiClient(
        storageService: storageService,
        secureStorageService: secureStorageService,
        authInterceptor: AuthInterceptor(
          tokenStore: tokenStore,
          sessionGeneration: generation,
          refreshToken: () async => const Success('unused'),
        ),
      )..dio.httpClientAdapter = adapter;
    }

    test(
      "criterion 1: a switch during the first send's read sends nothing",
      () async {
        final tokenStore = _SessionSwitchingTokenStore(generation, 1);
        final adapter = _RecordingAdapter([200]);
        final apiClient = buildClient(tokenStore, adapter);

        final thrown = await _thrownBy(apiClient.get('/me'));

        expect(tokenStore.authReads, 1, reason: 'the switch must have fired');
        expect(
          thrown,
          _isEndedSessionCancel,
          reason: "session A's caller must not receive session B's data",
        );
        expect(adapter.authorizations, isEmpty);
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );

    test(
      "criterion 2: a switch during a re-send's read sends only the first "
      'attempt',
      () async {
        final tokenStore = _SessionSwitchingTokenStore(generation, 2);
        final adapter = _RecordingAdapter([503, 200]);
        final apiClient = buildClient(tokenStore, adapter);

        final thrown = await _thrownBy(apiClient.get('/me'));

        expect(tokenStore.authReads, 2, reason: 'the switch must have fired');
        expect(thrown, _isEndedSessionCancel);
        expect(adapter.authorizations, ['Bearer USER-A']);
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );

    test(
      'criterion 3: with no switch the stored token is sent',
      () async {
        final tokenStore = _SessionSwitchingTokenStore(generation, 0);
        final adapter = _RecordingAdapter([503, 200]);
        final apiClient = buildClient(tokenStore, adapter);

        final response = await apiClient.get('/me');

        expect(response.statusCode, 200);
        expect(tokenStore.authReads, 2);
        expect(adapter.authorizations, ['Bearer USER-A', 'Bearer USER-A']);
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );
  });

  group('a 400 with a non-String body field (#305)', () {
    test('a list message surfaces as ServerException(400), not as a '
        'NetworkException', () async {
      final adapter = _CountingAdapter([
        _json(400, {
          'statusCode': 400,
          'message': ['email must be an email'],
          'error': 'Bad Request',
        }),
      ]);
      final apiClient = ApiClient(
        storageService: _MockStorageService(),
        secureStorageService: _MockSecureStorageService(),
        authInterceptor: AuthInterceptor(
          tokenStore: _InMemoryTokenStore(),
          refreshToken: () async => const Success('unused'),
        ),
      )..dio.httpClientAdapter = adapter;

      final thrown = await _thrownBy(
        apiClient.post('/users', data: {'email': 'nope'}),
      );

      expect(
        thrown,
        isA<ServerException>()
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.message, 'message', 'email must be an email'),
      );
      expect(thrown, isNot(isA<NetworkException>()));
    });
  });
}
