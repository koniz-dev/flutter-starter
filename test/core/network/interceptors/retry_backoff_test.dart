// RetryInterceptor's backoff doubles from the initial delay, keeps its
// jitter under the bound, and treats a GET's sendTimeout as transient
// (koniz-dev/flutter-starter#577, split from #376). The delays are measured
// on fake_async's virtual clock, so the test sleeps through none of them.

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_starter/core/network/interceptors/retry_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fails every request with [type], recording when each attempt arrived.
class _FailingAdapter implements HttpClientAdapter {
  _FailingAdapter(this.type, this.now);

  final DioExceptionType type;
  final Duration Function() now;
  final attempts = <Duration>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    attempts.add(now());
    throw DioException(requestOptions: options, type: type);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const initial = Duration(seconds: 1);
  const jitter = Duration(milliseconds: 500);

  ({List<Duration> attempts, Object? error}) run(
    DioExceptionType type, {
    String method = 'GET',
  }) {
    late _FailingAdapter adapter;
    Object? error;
    fakeAsync((async) {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      adapter = _FailingAdapter(type, () => async.elapsed);
      dio
        ..httpClientAdapter = adapter
        ..interceptors.add(RetryInterceptor(dio: dio));
      unawaited(
        dio
            .request<void>('/items', options: Options(method: method))
            .then<void>((_) {}, onError: (Object e) => error = e),
      );
      async
        ..elapse(const Duration(seconds: 30))
        ..flushMicrotasks();
    });
    return (attempts: adapter.attempts, error: error);
  }

  test('criterion 2: the delays are 1x, 2x and 4x the initial delay, '
      'each plus jitter under 500 ms', () {
    final result = run(DioExceptionType.connectionTimeout);

    expect(result.attempts, hasLength(4), reason: '1 attempt + 3 retries');
    expect(result.error, isA<DioException>());
    for (var retry = 1; retry <= 3; retry++) {
      final gap = result.attempts[retry] - result.attempts[retry - 1];
      final base = initial * (1 << (retry - 1));
      expect(gap, greaterThanOrEqualTo(base), reason: 'retry $retry');
      expect(gap, lessThan(base + jitter), reason: 'retry $retry');
    }
  });

  test('criterion 3: a GET failing with sendTimeout is retried', () {
    final result = run(DioExceptionType.sendTimeout);

    expect(result.attempts, hasLength(4));
    expect((result.error! as DioException).type, DioExceptionType.sendTimeout);
  });

  test('a POST failing with sendTimeout is not retried', () {
    final result = run(DioExceptionType.sendTimeout, method: 'POST');

    expect(result.attempts, hasLength(1));
  });

  test('maxJitter: Duration.zero removes the jitter entirely', () {
    late List<Duration> attempts;
    fakeAsync((async) {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      final adapter = _FailingAdapter(
        DioExceptionType.connectionTimeout,
        () => async.elapsed,
      );
      attempts = adapter.attempts;
      dio
        ..httpClientAdapter = adapter
        ..interceptors.add(
          RetryInterceptor(dio: dio, maxJitter: Duration.zero),
        );
      unawaited(
        dio.get<void>('/items').then<void>((_) {}, onError: (Object _) {}),
      );
      async
        ..elapse(const Duration(seconds: 30))
        ..flushMicrotasks();
    });

    expect(attempts, const [
      Duration.zero,
      Duration(seconds: 1),
      Duration(seconds: 3),
      Duration(seconds: 7),
    ]);
  });
}
