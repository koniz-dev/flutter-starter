import 'package:flutter_starter/core/performance/noop_performance_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NoOpPerformanceService', () {
    late NoOpPerformanceService service;

    setUp(() {
      service = NoOpPerformanceService();
    });

    test('startTrace returns null', () {
      expect(service.startTrace('test'), isNull);
    });

    test(
      'measureOperation executes operation and returns its result',
      () async {
        final result = await service.measureOperation(
          name: 'test',
          operation: () async => 'success',
        );
        expect(result, equals('success'));
      },
    );

    test('measureSyncOperation executes operation and returns its result', () {
      final result = service.measureSyncOperation(
        name: 'test',
        operation: () => 'success',
      );
      expect(result, equals('success'));
    });

    test(
      'measureSyncComputation executes computation and returns its result',
      () {
        final result = service.measureSyncComputation(
          operationName: 'test',
          computation: () => 'success',
        );
        expect(result, equals('success'));
      },
    );

    test('startHttpTrace returns null', () {
      expect(service.startHttpTrace('GET', '/path'), isNull);
    });

    test('startScreenTrace returns null', () {
      expect(service.startScreenTrace('HomeScreen'), isNull);
    });
  });

  group('NoOpPerformanceTrace', () {
    late NoOpPerformanceTrace trace;

    setUp(() {
      trace = NoOpPerformanceTrace();
    });

    test('start completes without error', () async {
      await expectLater(trace.start(), completes);
    });

    test('startSync completes without error', () {
      expect(() => trace.startSync(), returnsNormally);
    });

    test('stop completes without error', () async {
      await expectLater(trace.stop(), completes);
    });

    test('stopSync completes without error', () {
      expect(() => trace.stopSync(), returnsNormally);
    });

    test('incrementMetric completes without error', () {
      expect(() => trace.incrementMetric('metric', 1), returnsNormally);
    });

    test('putMetric completes without error', () {
      expect(() => trace.putMetric('metric', 1), returnsNormally);
    });

    test('putAttribute completes without error', () {
      expect(() => trace.putAttribute('attr', 'value'), returnsNormally);
    });

    test('putAttributes completes without error', () {
      expect(() => trace.putAttributes({'attr': 'value'}), returnsNormally);
    });

    test('getAttribute returns null', () {
      expect(trace.getAttribute('attr'), isNull);
    });

    test('getMetric returns null', () {
      expect(trace.getMetric('metric'), isNull);
    });
  });
}
