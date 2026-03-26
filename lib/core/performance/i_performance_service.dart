/// Abstract interface for performance monitoring
///
/// This interface decouples performance monitoring from any specific
/// implementation (e.g., Firebase Performance). The default implementation
/// is NoOpPerformanceService which does nothing, allowing the app to
/// run without any performance monitoring dependency.
///
/// To enable Firebase Performance, override performanceServiceProvider
/// with FirebasePerformanceService.
abstract class IPerformanceService {
  /// Returns true if performance monitoring is enabled
  bool get isEnabled;

  /// Start a custom trace
  ///
  /// Returns null if performance monitoring is disabled.
  IPerformanceTrace? startTrace(String name);

  /// Measure an async operation with automatic trace management
  Future<T> measureOperation<T>({
    required String name,
    required Future<T> Function() operation,
    Map<String, String>? attributes,
  });

  /// Measure a sync operation with automatic trace management
  T measureSyncOperation<T>({
    required String name,
    required T Function() operation,
    Map<String, String>? attributes,
  });

  /// Measure a sync computation with automatic trace management
  T measureSyncComputation<T>({
    required String operationName,
    required T Function() computation,
    Map<String, String>? attributes,
  });

  /// Create a HTTP request trace
  IPerformanceTrace? startHttpTrace(String method, String path);

  /// Create a screen trace
  IPerformanceTrace? startScreenTrace(String screenName);
}

/// Abstract interface for performance traces
///
/// Wraps trace operations for better abstraction and testability.
abstract class IPerformanceTrace {
  /// Start the trace (async)
  Future<void> start();

  /// Start the trace (sync)
  void startSync();

  /// Stop the trace (async)
  Future<void> stop();

  /// Stop the trace (sync)
  void stopSync();

  /// Increment a metric by the given value
  void incrementMetric(String metricName, int value);

  /// Set a metric to the given value
  void putMetric(String metricName, int value);

  /// Set an attribute on the trace
  void putAttribute(String name, String value);

  /// Set multiple attributes on the trace
  void putAttributes(Map<String, String> attributes);

  /// Get an attribute value
  String? getAttribute(String name);

  /// Get a metric value
  int? getMetric(String metricName);
}
