import 'dart:async';

import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/performance/i_performance_service.dart';
import 'package:flutter_starter/core/performance/noop_performance_service.dart'
    show NoOpPerformanceService;
import 'package:flutter_starter/core/performance/performance.dart'
    show NoOpPerformanceService;

/// Firebase Performance monitoring service
///
/// This is the Firebase-backed implementation of [IPerformanceService].
/// It is NOT used by default â€” the default is [NoOpPerformanceService].
///
/// To enable Firebase Performance, override the provider:
/// ```dart
/// final performanceServiceProvider = Provider<IPerformanceService>((ref) {
///   return FirebasePerformanceService();
/// });
/// ```
class FirebasePerformanceService implements IPerformanceService {
  /// Creates a [FirebasePerformanceService] instance
  FirebasePerformanceService() : _performance = _getPerformanceInstance();

  final FirebasePerformance? _performance;

  static FirebasePerformance? _getPerformanceInstance() {
    try {
      return FirebasePerformance.instance;
    } on Exception {
      return null;
    }
  }

  @override
  bool get isEnabled => AppConfig.enablePerformanceMonitoring;

  @override
  IPerformanceTrace? startTrace(String name) {
    if (!isEnabled || _performance == null) return null;
    try {
      final trace = _performance.newTrace(name);
      return FirebasePerformanceTrace(trace);
    } on Exception {
      return null;
    }
  }

  @override
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

  @override
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

  @override
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

  @override
  IPerformanceTrace? startHttpTrace(String method, String path) {
    if (!isEnabled) return null;

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

  @override
  IPerformanceTrace? startScreenTrace(String screenName) {
    if (!isEnabled) return null;

    final traceName = 'screen_$screenName';
    final trace = startTrace(traceName);
    if (trace != null) {
      trace.putAttribute('screen_name', screenName);
    }
    return trace;
  }

  /// Sanitize path to avoid creating too many unique traces
  String _sanitizePath(String path) {
    final withoutQuery = path.split('?').first;
    return withoutQuery
        .replaceAll(RegExp(r'/\d+'), '/:id')
        .replaceAll(RegExp('/[a-f0-9-]{36}'), '/:uuid')
        .replaceAll(RegExp('/[a-zA-Z0-9]{20,}'), '/:token');
  }
}

/// Firebase-backed wrapper around Firebase [Trace]
class FirebasePerformanceTrace implements IPerformanceTrace {
  /// Creates a [FirebasePerformanceTrace] wrapping a Firebase [Trace]
  FirebasePerformanceTrace(this._trace);

  final Trace _trace;

  @override
  Future<void> start() async {
    try {
      await _trace.start();
    } on Exception {
      // Ignore errors if Firebase Performance is not available
    }
  }

  @override
  void startSync() {
    try {
      unawaited(_trace.start());
    } on Exception {
      // Ignore errors if Firebase Performance is not available
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _trace.stop();
    } on Exception {
      // Ignore errors if Firebase Performance is not available
    }
  }

  @override
  void stopSync() {
    try {
      unawaited(_trace.stop());
    } on Exception {
      // Ignore errors if Firebase Performance is not available
    }
  }

  @override
  void incrementMetric(String metricName, int value) {
    try {
      _trace.incrementMetric(metricName, value);
    } on Exception {
      // Ignore errors if Firebase Performance is not available
    }
  }

  @override
  void putMetric(String metricName, int value) {
    try {
      _trace.incrementMetric(metricName, value);
    } on Exception {
      // Ignore errors if Firebase Performance is not available
    }
  }

  @override
  void putAttribute(String name, String value) {
    try {
      _trace.putAttribute(name, value);
    } on Exception {
      // Ignore errors if Firebase Performance is not available
    }
  }

  @override
  void putAttributes(Map<String, String> attributes) {
    for (final entry in attributes.entries) {
      putAttribute(entry.key, entry.value);
    }
  }

  @override
  String? getAttribute(String name) {
    try {
      return _trace.getAttribute(name);
    } on Exception {
      return null;
    }
  }

  @override
  int? getMetric(String metricName) {
    try {
      return _trace.getMetric(metricName);
    } on Exception {
      return null;
    }
  }
}
