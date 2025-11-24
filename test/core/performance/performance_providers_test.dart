import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/network/interceptors/performance_interceptor.dart';
import 'package:flutter_starter/core/performance/performance_providers.dart';
import 'package:flutter_starter/core/performance/performance_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('performanceServiceProvider', () {
    test('should provide PerformanceService instance', () {
      final container = ProviderContainer();
      final service = container.read(performanceServiceProvider);

      expect(service, isA<PerformanceService>());
    });

    test('should provide singleton instance', () {
      final container = ProviderContainer();
      final service1 = container.read(performanceServiceProvider);
      final service2 = container.read(performanceServiceProvider);

      expect(service1, same(service2));
    });

    test('should be accessible as Provider', () {
      final container = ProviderContainer();
      expect(
        () => container.read(performanceServiceProvider),
        returnsNormally,
      );
    });
  });

  group('performanceInterceptorProvider', () {
    test('should provide PerformanceInterceptor instance', () {
      final container = ProviderContainer();
      final interceptor = container.read(performanceInterceptorProvider);

      expect(interceptor, isA<PerformanceInterceptor>());
    });

    test('should provide singleton instance', () {
      final container = ProviderContainer();
      final interceptor1 = container.read(performanceInterceptorProvider);
      final interceptor2 = container.read(performanceInterceptorProvider);

      expect(interceptor1, same(interceptor2));
    });

    test('should depend on performanceServiceProvider', () {
      final container = ProviderContainer();
      final interceptor = container.read(performanceInterceptorProvider);
      final service = container.read(performanceServiceProvider);

      expect(interceptor, isA<PerformanceInterceptor>());
      expect(service, isA<PerformanceService>());
    });

    test('should be accessible as Provider', () {
      final container = ProviderContainer();
      expect(
        () => container.read(performanceInterceptorProvider),
        returnsNormally,
      );
    });
  });

  group('Provider Integration', () {
    test('should work with ProviderContainer', () {
      final container = ProviderContainer();
      expect(
        () {
          container.read(performanceServiceProvider);
          container.read(performanceInterceptorProvider);
        },
        returnsNormally,
      );
    });

    test('should handle multiple reads', () {
      final container = ProviderContainer();
      for (var i = 0; i < 5; i++) {
        final service = container.read(performanceServiceProvider);
        final interceptor = container.read(performanceInterceptorProvider);
        expect(service, isA<PerformanceService>());
        expect(interceptor, isA<PerformanceInterceptor>());
      }
    });
  });
}

