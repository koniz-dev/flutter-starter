import 'package:flutter/material.dart';
import 'package:flutter_starter/core/utils/performance_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PerformanceMonitor', () {
    group('measureAsync', () {
      test('should measure async operation duration', () async {
        final duration = await PerformanceMonitor.measureAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });

        expect(duration, greaterThanOrEqualTo(90));
        expect(duration, lessThan(200));
      });

      test('should return 0 for instant operations', () async {
        final duration = await PerformanceMonitor.measureAsync(() async {
          // Instant operation
        });

        expect(duration, greaterThanOrEqualTo(0));
        expect(duration, lessThan(10));
      });

      test('should handle errors in async operations', () async {
        expect(
          () => PerformanceMonitor.measureAsync(() async {
            throw Exception('Test error');
          }),
          throwsException,
        );
      });
    });

    group('measureSync', () {
      test('should measure sync operation duration', () {
        final duration = PerformanceMonitor.measureSync(() {
          // Simulate some work
          for (var i = 0; i < 1000; i++) {
            // Do some computation
            final _ = i * 2;
          }
        });

        expect(duration, greaterThanOrEqualTo(0));
        expect(duration, lessThan(100));
      });

      test('should return 0 for instant operations', () {
        final duration = PerformanceMonitor.measureSync(() {
          // Instant operation
        });

        expect(duration, greaterThanOrEqualTo(0));
        expect(duration, lessThan(10));
      });

      test('should handle errors in sync operations', () {
        expect(
          () => PerformanceMonitor.measureSync(() {
            throw Exception('Test error');
          }),
          throwsException,
        );
      });
    });

    group('monitorFrameRate', () {
      test('should not monitor in release mode', () {
        // In test environment, kDebugMode might be false
        // This test verifies the method exists and doesn't crash
        expect(
          () => PerformanceMonitor.monitorFrameRate(
            onLowFps: (fps) {},
          ),
          returnsNormally,
        );
      });
    });

    group('getMemoryUsage', () {
      test('should return memory usage map', () {
        final usage = PerformanceMonitor.getMemoryUsage();

        expect(usage, isA<Map<String, dynamic>>());
        expect(usage['heapSize'], isNotNull);
        expect(usage['externalSize'], isNotNull);
        expect(usage['timestamp'], isA<String>());
      });
    });

    group('logMetrics', () {
      test('should log metrics in debug mode', () {
        // This test verifies the method exists and doesn't crash
        expect(
          () => PerformanceMonitor.logMetrics('test_operation', 100),
          returnsNormally,
        );
      });
    });

    group('createReport', () {
      test('should create performance report', () {
        final report = PerformanceMonitor.createReport(
          operation: 'test_operation',
          durationMs: 150,
          additionalData: {'key': 'value'},
        );

        expect(report, isA<Map<String, dynamic>>());
        expect(report['operation'], 'test_operation');
        expect(report['duration_ms'], 150);
        expect(report['key'], 'value');
        expect(report['timestamp'], isA<String>());
      });

      test('should create report without additional data', () {
        final report = PerformanceMonitor.createReport(
          operation: 'test_operation',
          durationMs: 200,
        );

        expect(report, isA<Map<String, dynamic>>());
        expect(report['operation'], 'test_operation');
        expect(report['duration_ms'], 200);
        expect(report['timestamp'], isA<String>());
      });
    });
  });

  group('PerformanceWidget', () {
    testWidgets('should measure build performance in debug mode',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PerformanceWidget(
            name: 'test_widget',
            child: Text('Test'),
          ),
        ),
      );

      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('should render child widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PerformanceWidget(
            name: 'test_widget',
            child: Text('Test Content'),
          ),
        ),
      );

      expect(find.text('Test Content'), findsOneWidget);
    });
  });
}
