// A stale cache entry is a fallback for a refetch that failed, so it must be
// served only after the rest of the chain has seen that failure: the retries
// run (one of them may fetch a fresh answer), the failure is logged, and the
// refetch's performance trace is stopped. Serving it from CacheInterceptor,
// which sits first in the chain, ended the chain before any of those ran.
// These tests drive the assembled ApiClient, anonymous so the cache applies.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/performance/i_performance_service.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/utils/date_formatter.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/in_memory_stores.dart';

class _MockSecureStorageService extends Mock implements SecureStorageService {}

/// Replies from a script: an HTTP status, or a [DioExceptionType] to throw.
/// The last entry repeats. Each 200 body carries its hit number.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._script);

  final List<Object> _script;
  int hits = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final step = _script[hits < _script.length ? hits : _script.length - 1];
    hits++;
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

class _Trace implements IPerformanceTrace {
  bool stopped = false;

  @override
  String? getAttribute(String name) => null;

  @override
  int? getMetric(String metricName) => null;

  @override
  void incrementMetric(String metricName, int value) {}

  @override
  void putAttribute(String name, String value) {}

  @override
  void putAttributes(Map<String, String> values) {}

  @override
  void putMetric(String metricName, int value) {}

  @override
  Future<void> start() async {}

  @override
  void startSync() {}

  @override
  Future<void> stop() async => stopSync();

  @override
  void stopSync() => stopped = true;
}

class _PerformanceService implements IPerformanceService {
  final List<_Trace> traces = [];

  @override
  bool get isEnabled => true;

  @override
  IPerformanceTrace? startHttpTrace(String method, String path) {
    final trace = _Trace();
    traces.add(trace);
    return trace;
  }

  @override
  IPerformanceTrace? startScreenTrace(String screenName) => null;

  @override
  IPerformanceTrace? startTrace(String name) => null;

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

class _LoggingService extends LoggingService {
  _LoggingService() : super(enableLogging: false);

  final List<String> errors = [];

  @override
  void error(
    String message, {
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  }) => errors.add(message);
}

void main() {
  late InMemoryStorage storage;
  late _PerformanceService performance;
  late _LoggingService logging;

  ({ApiClient client, _ScriptedAdapter adapter}) build(List<Object> script) {
    final adapter = _ScriptedAdapter(script);
    final client = ApiClient(
      storageService: storage,
      secureStorageService: _MockSecureStorageService(),
      authInterceptor: AuthInterceptor(
        tokenStore: InMemoryTokenStore(),
        refreshToken: () async => const Success('unused'),
      ),
      loggingService: logging,
      performanceService: performance,
      retryInitialDelay: Duration.zero,
      retryMaxJitter: Duration.zero,
    )..dio.httpClientAdapter = adapter;
    return (client: client, adapter: adapter);
  }

  /// Makes every cached entry two hours old: past the default maxAge, inside
  /// the default maxStale.
  void ageCache() {
    final stamp = DateFormatter.formatIso8601(
      DateTime.now().subtract(const Duration(hours: 2)),
    );
    for (final key in storage.values.keys.toList()) {
      if (key.startsWith('http_cache_timestamp_')) storage.values[key] = stamp;
    }
  }

  setUp(() {
    storage = InMemoryStorage();
    performance = _PerformanceService();
    logging = _LoggingService();
  });

  test('a transient refetch failure is retried before the stale entry is '
      'served, and the retry answer wins', () async {
    final h = build([200, DioExceptionType.connectionError, 200]);
    await h.client.get('/feed');
    ageCache();

    final response = await h.client.get('/feed');

    expect(h.adapter.hits, 3, reason: 'the refetch must be retried');
    expect(response.data, {'hit': 3});
    expect(
      performance.traces.map((t) => t.stopped),
      everyElement(isTrue),
      reason: 'every trace, the refetch included, must be stopped',
    );
  });

  test('when every retry fails, the stale entry is served after the failure '
      'is logged and the refetch trace is stopped', () async {
    final h = build([200, DioExceptionType.connectionError]);
    await h.client.get('/feed');
    ageCache();

    final response = await h.client.get('/feed');

    // The first fetch, the refetch and RetryInterceptor's three retries.
    expect(h.adapter.hits, 5);
    expect(response.data, {'hit': 1});
    expect(performance.traces, hasLength(2));
    expect(
      performance.traces.map((t) => t.stopped),
      everyElement(isTrue),
      reason: 'the refetch trace must be stopped',
    );
    expect(logging.errors, isNotEmpty, reason: 'the failure must be logged');
  });
}
