import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/network/interceptors/performance_interceptor.dart';
import 'package:flutter_starter/core/performance/i_performance_service.dart';
import 'package:flutter_starter/core/performance/noop_performance_service.dart';

/// Provider for [IPerformanceService] instance
///
/// By default, this uses [NoOpPerformanceService] which has zero external
/// dependencies. To enable Firebase Performance monitoring, override this
/// provider:
///
/// ```dart
/// final performanceServiceProvider = Provider<IPerformanceService>((ref) {
///   return FirebasePerformanceService();
/// });
/// ```
final performanceServiceProvider = Provider<IPerformanceService>((ref) {
  return NoOpPerformanceService();
});

/// Provider for [PerformanceInterceptor] instance
///
/// This provider creates a singleton instance of [PerformanceInterceptor] that
/// automatically tracks HTTP request performance.
///
/// The interceptor should be added to the Dio instance in ApiClient.
final performanceInterceptorProvider = Provider<PerformanceInterceptor>((ref) {
  final performanceService = ref.watch(performanceServiceProvider);
  return PerformanceInterceptor(performanceService: performanceService);
});
