import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/storage/storage_logging_mixin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingService extends Mock implements LoggingService {}

class TestStorageService with StorageLoggingMixin {
  TestStorageService(this.loggingService);

  @override
  final LoggingService loggingService;
}

void main() {
  group('StorageLoggingMixin', () {
    late MockLoggingService mockLoggingService;
    late TestStorageService storageService;

    setUp(() {
      mockLoggingService = MockLoggingService();
      storageService = TestStorageService(mockLoggingService);
    });

    group('logStorageRead', () {
      test('should log storage read operation', () {
        when(
          () => mockLoggingService.debug(
            any(),
            context: any(named: 'context'),
          ),
        ).thenReturn(null);

        storageService.logStorageRead(
          'getString',
          'test_key',
          value: 'test_value',
        );

        verify(
          () => mockLoggingService.debug(
            'Storage Read: getString',
            context: any(named: 'context'),
          ),
        ).called(1);
      });

      test('should log storage read without value', () {
        when(
          () => mockLoggingService.debug(
            any(),
            context: any(named: 'context'),
          ),
        ).thenReturn(null);

        storageService.logStorageRead('getString', 'test_key');

        verify(
          () => mockLoggingService.debug(
            'Storage Read: getString',
            context: any(named: 'context'),
          ),
        ).called(1);
      });
    });

    group('logStorageWrite', () {
      test('should log storage write operation', () {
        when(
          () => mockLoggingService.debug(
            any(),
            context: any(named: 'context'),
          ),
        ).thenReturn(null);

        storageService.logStorageWrite(
          'setString',
          'test_key',
          value: 'test_value',
        );

        verify(
          () => mockLoggingService.debug(
            'Storage Write: setString',
            context: any(named: 'context'),
          ),
        ).called(1);
      });

      test('should sanitize sensitive values', () {
        when(
          () => mockLoggingService.debug(
            any(),
            context: any(named: 'context'),
          ),
        ).thenReturn(null);

        storageService.logStorageWrite(
          'setString',
          'password',
          value: 'my_secret_password',
        );

        verify(
          () => mockLoggingService.debug(
            'Storage Write: setString',
            context: any(
              that: predicate<Map<String, dynamic>>(
                (context) => context['value'] == '***REDACTED***',
              ),
              named: 'context',
            ),
          ),
        ).called(1);
      });

      test('should truncate long values', () {
        when(
          () => mockLoggingService.debug(
            any(),
            context: any(named: 'context'),
          ),
        ).thenReturn(null);

        final longValue = 'a' * 200;
        storageService.logStorageWrite(
          'setString',
          'test_key',
          value: longValue,
        );

        verify(
          () => mockLoggingService.debug(
            'Storage Write: setString',
            context: any(
              that: predicate<Map<String, dynamic>>(
                (context) =>
                    (context['value'] as String).endsWith('... (truncated)'),
              ),
              named: 'context',
            ),
          ),
        ).called(1);
      });
    });

    group('logStorageDelete', () {
      test('should log storage delete operation', () {
        when(
          () => mockLoggingService.debug(
            any(),
            context: any(named: 'context'),
          ),
        ).thenReturn(null);

        storageService.logStorageDelete('remove', 'test_key');

        verify(
          () => mockLoggingService.debug(
            'Storage Delete: remove',
            context: any(named: 'context'),
          ),
        ).called(1);
      });
    });

    group('logStorageError', () {
      test('should log storage error', () {
        when(
          () => mockLoggingService.error(
            any(),
            context: any(named: 'context'),
            error: any(named: 'error'),
            stackTrace: any(named: 'stackTrace'),
          ),
        ).thenReturn(null);

        final error = Exception('Test error');
        final stackTrace = StackTrace.current;

        storageService.logStorageError(
          'getString',
          'test_key',
          error,
          stackTrace: stackTrace,
        );

        verify(
          () => mockLoggingService.error(
            'Storage Error: getString',
            context: any(named: 'context'),
            error: error,
            stackTrace: stackTrace,
          ),
        ).called(1);
      });

      test('should log storage error without stack trace', () {
        when(
          () => mockLoggingService.error(
            any(),
            context: any(named: 'context'),
            error: any(named: 'error'),
            stackTrace: any(named: 'stackTrace'),
          ),
        ).thenReturn(null);

        final error = Exception('Test error');

        storageService.logStorageError('getString', 'test_key', error);

        verify(
          () => mockLoggingService.error(
            'Storage Error: getString',
            context: any(named: 'context'),
            error: error,
          ),
        ).called(1);
      });
    });

    group('value sanitization', () {
      test('should sanitize password values', () {
        when(
          () => mockLoggingService.debug(
            any(),
            context: any(named: 'context'),
          ),
        ).thenReturn(null);

        storageService.logStorageWrite(
          'setString',
          'user_password',
          value: 'secret123',
        );

        verify(
          () => mockLoggingService.debug(
            any(),
            context: any(
              that: predicate<Map<String, dynamic>>(
                (context) => context['value'] == '***REDACTED***',
              ),
              named: 'context',
            ),
          ),
        ).called(1);
      });

      test('should sanitize token values', () {
        when(
          () => mockLoggingService.debug(
            any(),
            context: any(named: 'context'),
          ),
        ).thenReturn(null);

        storageService.logStorageWrite(
          'setString',
          'auth_token',
          value: 'token123',
        );

        verify(
          () => mockLoggingService.debug(
            any(),
            context: any(
              that: predicate<Map<String, dynamic>>(
                (context) => context['value'] == '***REDACTED***',
              ),
              named: 'context',
            ),
          ),
        ).called(1);
      });

      test('should not sanitize non-sensitive values', () {
        when(
          () => mockLoggingService.debug(
            any(),
            context: any(named: 'context'),
          ),
        ).thenReturn(null);

        storageService.logStorageWrite(
          'setString',
          'user_name',
          value: 'John Doe',
        );

        verify(
          () => mockLoggingService.debug(
            any(),
            context: any(
              that: predicate<Map<String, dynamic>>(
                (context) => context['value'] == 'John Doe',
              ),
              named: 'context',
            ),
          ),
        ).called(1);
      });
    });
  });
}
