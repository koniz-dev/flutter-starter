import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/network/interceptors/performance_interceptor.dart';
import 'package:flutter_starter/core/performance/performance_service.dart';

/// Provider for [PerformanceService] instance
///
/// This provider creates a singleton instance of [PerformanceService] that can
/// be used throughout the application for performance monitoring.
///
/// The service automatically respects the ENABLE_PERFORMANCE_MONITORING flag
/// from AppConfig.
final performanceServiceProvider = Provider<PerformanceService>((ref) {
  return PerformanceService();
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
