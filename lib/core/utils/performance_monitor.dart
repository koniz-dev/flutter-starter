import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Performance monitoring utility
///
/// This class provides utilities for monitoring app performance metrics
/// such as frame rate, memory usage, and operation timing.
class PerformanceMonitor {
  PerformanceMonitor._();

  /// Measures the execution time of an async operation
  ///
  /// Returns the duration in milliseconds
  static Future<int> measureAsync(Future<void> Function() operation) async {
    final stopwatch = Stopwatch()..start();
    await operation();
    stopwatch.stop();
    return stopwatch.elapsedMilliseconds;
  }

  /// Measures the execution time of a sync operation
  ///
  /// Returns the duration in milliseconds
  static int measureSync(void Function() operation) {
    final stopwatch = Stopwatch()..start();
    operation();
    stopwatch.stop();
    return stopwatch.elapsedMilliseconds;
  }

  /// Monitors frame rate and reports when it drops below threshold
  ///
  /// [threshold] - Minimum acceptable FPS (default: 55)
  /// [onLowFps] - Callback when FPS drops below threshold
  static void monitorFrameRate({
    double threshold = 55.0,
    void Function(double fps)? onLowFps,
  }) {
    if (!kDebugMode) return;

    var frameCount = 0;
    DateTime? lastTime;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      frameCount++;
      final now = DateTime.now();

      if (lastTime != null) {
        final elapsed = now.difference(lastTime!).inMilliseconds;
        if (elapsed >= 1000) {
          final fps = (frameCount / elapsed) * 1000;
          if (fps < threshold && onLowFps != null) {
            onLowFps(fps);
          }
          frameCount = 0;
          lastTime = now;
        }
      } else {
        lastTime = now;
      }
    });
  }

  /// Gets current memory usage (approximate)
  ///
  /// Note: This is an approximation and may not be accurate on all platforms
  static Map<String, dynamic> getMemoryUsage() {
    // Note: Flutter doesn't provide direct memory access
    // This is a placeholder for future implementation
    return {
      'heapSize': 'N/A',
      'externalSize': 'N/A',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Logs performance metrics
  static void logMetrics(String operation, int durationMs) {
    if (kDebugMode) {
      debugPrint('⏱️ Performance: $operation took ${durationMs}ms');
    }
  }

  /// Creates a performance report
  static Map<String, dynamic> createReport({
    required String operation,
    required int durationMs,
    Map<String, dynamic>? additionalData,
  }) {
    return {
      'operation': operation,
      'duration_ms': durationMs,
      'timestamp': DateTime.now().toIso8601String(),
      ...?additionalData,
    };
  }
}

/// Widget performance wrapper
///
/// Use this widget to measure build performance of child widgets
class PerformanceWidget extends StatelessWidget {
  /// Creates a [PerformanceWidget] with the given [child] and [name]
  const PerformanceWidget({
    required this.child,
    required this.name,
    super.key,
  });

  /// Child widget to measure
  final Widget child;

  /// Name of the widget for logging
  final String name;

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      final stopwatch = Stopwatch()..start();
      final result = child;
      stopwatch.stop();
      PerformanceMonitor.logMetrics(
        'Build: $name',
        stopwatch.elapsedMilliseconds,
      );
      return result;
    }
    return child;
  }
}
