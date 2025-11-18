import 'dart:async';

import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter_starter/core/config/app_config.dart';

/// Performance monitoring service that wraps Firebase Performance
///
/// This service provides a clean API for performance monitoring while:
/// - Respecting the ENABLE_PERFORMANCE_MONITORING flag
/// - Providing abstraction over Firebase Performance
/// - Being testable and non-intrusive
///
/// Usage:
/// ```dart
/// final service = PerformanceService();
/// final trace = service.startTrace('api_call');
/// // ... perform operation ...
/// await trace?.stop();
/// ```
class PerformanceService {
  /// Creates a [PerformanceService] instance
  PerformanceService() : _performance = FirebasePerformance.instance;

  final FirebasePerformance _performance;

  /// Returns true if performance monitoring is enabled
  bool get isEnabled => AppConfig.enablePerformanceMonitoring;

  /// Start a custom trace
  ///
  /// Returns null if performance monitoring is disabled.
  ///
  /// [name] - The name of the trace (max 100 characters)
  /// Returns a [PerformanceTrace] that can be used to record metrics and stop
  PerformanceTrace? startTrace(String name) {
    if (!isEnabled) return null;
    try {
      final trace = _performance.newTrace(name);
      return PerformanceTrace(trace);
    } on Exception {
      // If Firebase Performance is not initialized, return null
      return null;
    }
  }

  /// Measure an async operation with automatic trace management
  ///
  /// This method automatically starts a trace, executes the operation,
  /// records success/error metrics, and stops the trace.
  ///
  /// [name] - The name of the trace
  /// [operation] - The async operation to measure
  /// [attributes] - Optional attributes to add to the trace
  /// Returns the result of the operation
  Future<T> measureOperation<T>({
    required String name,
    required Future<T> Function() operation,
    Map<String, String>? attributes,
  }) async {
    if (!isEnabled) {
      return operation();
    }

    final trace = startTrace(name);
    if (trace == null) {
      return operation();
    }

    try {
      await trace.start();
      if (attributes != null) {
        trace.putAttributes(attributes);
      }

      final result = await operation();
      trace.putMetric('success', 1);
      return result;
    } catch (e) {
      trace
        ..putMetric('error', 1)
        ..putAttribute('error_type', e.runtimeType.toString());
      rethrow;
    } finally {
      await trace.stop();
    }
  }

  /// Measure a sync operation with automatic trace management
  ///
  /// This method automatically starts a trace, executes the operation,
  /// records success/error metrics, and stops the trace.
  ///
  /// [name] - The name of the trace
  /// [operation] - The sync operation to measure
  /// [attributes] - Optional attributes to add to the trace
  /// Returns the result of the operation
  T measureSyncOperation<T>({
    required String name,
    required T Function() operation,
    Map<String, String>? attributes,
  }) {
    if (!isEnabled) {
      return operation();
    }

    final trace = startTrace(name);
    if (trace == null) {
      return operation();
    }

    try {
      trace.startSync();
      if (attributes != null) {
        trace.putAttributes(attributes);
      }

      final result = operation();
      trace.putMetric('success', 1);
      return result;
    } catch (e) {
      trace
        ..putMetric('error', 1)
        ..putAttribute('error_type', e.runtimeType.toString());
      rethrow;
    } finally {
      trace.stopSync();
    }
  }

  /// Measure a sync computation with automatic trace management
  ///
  /// This is a convenience method for measuring sync computations.
  ///
  /// [operationName] - The name of the operation
  /// [computation] - The sync computation to measure
  /// [attributes] - Optional attributes to add to the trace
  /// Returns the result of the computation
  T measureSyncComputation<T>({
    required String operationName,
    required T Function() computation,
    Map<String, String>? attributes,
  }) {
    return measureSyncOperation<T>(
      name: 'computation_$operationName',
      operation: computation,
      attributes: attributes,
    );
  }

  /// Create a HTTP request trace
  ///
  /// This is a convenience method for tracking HTTP requests.
  /// The trace name will be formatted as: `"http_<method>_<path>"`
  ///
  /// [method] - HTTP method (GET, POST, etc.)
  /// [path] - Request path
  /// Returns a [PerformanceTrace] configured for HTTP tracking
  PerformanceTrace? startHttpTrace(String method, String path) {
    if (!isEnabled) return null;

    // Sanitize path to avoid too many unique traces
    final sanitizedPath = _sanitizePath(path);
    final traceName = 'http_${method.toLowerCase()}_$sanitizedPath';
    final trace = startTrace(traceName);
    if (trace != null) {
      trace
        ..putAttribute('http_method', method)
        ..putAttribute('http_path', path);
    }
    return trace;
  }

  /// Create a screen trace
  ///
  /// This is a convenience method for tracking screen load times.
  /// The trace name will be formatted as: `"screen_<screenName>"`
  ///
  /// [screenName] - Name of the screen
  /// Returns a [PerformanceTrace] configured for screen tracking
  PerformanceTrace? startScreenTrace(String screenName) {
    if (!isEnabled) return null;

    final traceName = 'screen_$screenName';
    final trace = startTrace(traceName);
    if (trace != null) {
      trace.putAttribute('screen_name', screenName);
    }
    return trace;
  }

  /// Sanitize path to avoid creating too many unique traces
  ///
  /// Replaces dynamic segments (like IDs) with placeholders
  String _sanitizePath(String path) {
    // Remove query parameters
    final withoutQuery = path.split('?').first;
    // Replace common ID patterns with placeholders
    return withoutQuery
        .replaceAll(RegExp(r'/\d+'), '/:id')
        .replaceAll(RegExp('/[a-f0-9-]{36}'), '/:uuid')
        .replaceAll(RegExp('/[a-zA-Z0-9]{20,}'), '/:token');
  }
}

/// Wrapper around Firebase Trace for better abstraction and testability
class PerformanceTrace {
  /// Creates a [PerformanceTrace] wrapping a Firebase [Trace]
  PerformanceTrace(this._trace);

  final Trace _trace;

  /// Start the trace (async)
  Future<void> start() async {
    try {
      await _trace.start();
    } on Exception {
      // Ignore errors if Firebase Performance is not available
    }
  }

  /// Start the trace (sync)
  void startSync() {
    try {
      unawaited(_trace.start());
    } on Exception {
      // Ignore errors if Firebase Performance is not available
    }
  }

  /// Stop the trace (async)
  Future<void> stop() async {
    try {
      await _trace.stop();
    } on Exception {
      // Ignore errors if Firebase Performance is not available
    }
  }

  /// Stop the trace (sync)
  void stopSync() {
    try {
      unawaited(_trace.stop());
    } on Exception {
      // Ignore errors if Firebase Performance is not available
    }
  }

  /// Increment a metric by the given value
  void incrementMetric(String metricName, int value) {
    try {
      _trace.incrementMetric(metricName, value);
    } on Exception {
      // Ignore errors if Firebase Performance is not available
    }
  }

  /// Set a metric to the given value
  ///
  /// Note: Firebase Performance only supports incrementing metrics.
  /// This method increments the metric by the given value. For setting
  /// a specific value, use incrementMetric with the desired value directly.
  void putMetric(String metricName, int value) {
    try {
      // Firebase Performance only supports incrementing, so we increment by
      // value. If you need to set to a specific value, track the current value
      // separately
      _trace.incrementMetric(metricName, value);
    } on Exception {
      // Ignore errors if Firebase Performance is not available
    }
  }

  /// Set an attribute on the trace
  ///
  /// [name] - Attribute name (max 40 characters)
  /// [value] - Attribute value (max 100 characters)
  void putAttribute(String name, String value) {
    try {
      _trace.putAttribute(name, value);
    } on Exception {
      // Ignore errors if Firebase Performance is not available
    }
  }

  /// Set multiple attributes on the trace
  void putAttributes(Map<String, String> attributes) {
    for (final entry in attributes.entries) {
      putAttribute(entry.key, entry.value);
    }
  }

  /// Get an attribute value
  String? getAttribute(String name) {
    try {
      return _trace.getAttribute(name);
    } on Exception {
      return null;
    }
  }

  /// Get a metric value
  int? getMetric(String metricName) {
    try {
      return _trace.getMetric(metricName);
    } on Exception {
      return null;
    }
  }
}
