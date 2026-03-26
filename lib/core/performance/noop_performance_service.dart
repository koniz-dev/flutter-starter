import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/performance/i_performance_service.dart';

/// No-operation performance service (default implementation)
///
/// This implementation does nothing and has zero external dependencies.
/// It is the default implementation used when no performance monitoring
/// backend is configured.
///
/// To enable real performance monitoring, override performanceServiceProvider
/// with a concrete implementation like FirebasePerformanceService.
class NoOpPerformanceService implements IPerformanceService {
  @override
  bool get isEnabled => AppConfig.enablePerformanceMonitoring;

  @override
  IPerformanceTrace? startTrace(String name) => null;

  @override
  Future<T> measureOperation<T>({
    required String name,
    required Future<T> Function() operation,
    Map<String, String>? attributes,
  }) => operation();

  @override
  T measureSyncOperation<T>({
    required String name,
    required T Function() operation,
    Map<String, String>? attributes,
  }) => operation();

  @override
  T measureSyncComputation<T>({
    required String operationName,
    required T Function() computation,
    Map<String, String>? attributes,
  }) => computation();

  @override
  IPerformanceTrace? startHttpTrace(String method, String path) => null;

  @override
  IPerformanceTrace? startScreenTrace(String screenName) => null;
}

/// No-operation performance trace
///
/// Does nothing for all trace operations.
class NoOpPerformanceTrace implements IPerformanceTrace {
  @override
  Future<void> start() async {}

  @override
  void startSync() {}

  @override
  Future<void> stop() async {}

  @override
  void stopSync() {}

  @override
  void incrementMetric(String metricName, int value) {}

  @override
  void putMetric(String metricName, int value) {}

  @override
  void putAttribute(String name, String value) {}

  @override
  void putAttributes(Map<String, String> attributes) {}

  @override
  String? getAttribute(String name) => null;

  @override
  int? getMetric(String metricName) => null;
}
