import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/logging/logging_providers.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('loggingServiceProvider', () {
    test('provides a LoggingService instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(loggingServiceProvider);

      expect(service, isA<LoggingService>());
    });

    test('returns the same instance on multiple reads', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service1 = container.read(loggingServiceProvider);
      final service2 = container.read(loggingServiceProvider);

      expect(identical(service1, service2), isTrue);
    });

    test('disposes service when container is disposed', () {
      final container = ProviderContainer();
      final service = container.read(loggingServiceProvider);

      expect(service, isA<LoggingService>());

      // Should not throw when container is disposed
      expect(container.dispose, returnsNormally);
    });

    test('service can log after being provided', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(loggingServiceProvider);

      expect(() => service.info('test message'), returnsNormally);
      expect(() => service.debug('debug message'), returnsNormally);
      expect(() => service.warning('warning message'), returnsNormally);
      expect(
        () => service.error('error message', error: Exception('err')),
        returnsNormally,
      );
    });

    test('each container creates independent service instances', () {
      final container1 = ProviderContainer();
      final container2 = ProviderContainer();
      addTearDown(container1.dispose);
      addTearDown(container2.dispose);

      final service1 = container1.read(loggingServiceProvider);
      final service2 = container2.read(loggingServiceProvider);

      expect(identical(service1, service2), isFalse);
    });
  });
}
