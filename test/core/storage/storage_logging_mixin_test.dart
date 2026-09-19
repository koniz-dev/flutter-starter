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
          () => mockLoggingService.debug(any(), context: any(named: 'context')),
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
          () => mockLoggingService.debug(any(), context: any(named: 'context')),
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
          () => mockLoggingService.debug(any(), context: any(named: 'context')),
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
          () => mockLoggingService.debug(any(), context: any(named: 'context')),
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
          () => mockLoggingService.debug(any(), context: any(named: 'context')),
        ).thenReturn(null);

        final longValue = 'a' * 200;
        // A non-sensitive key: redaction is decided by the key now, and
        // 'test_key' would be redacted before truncation could apply.
        storageService.logStorageWrite(
          'setString',
          'user_note',
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
          () => mockLoggingService.debug(any(), context: any(named: 'context')),
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
          () => mockLoggingService.debug(any(), context: any(named: 'context')),
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
          () => mockLoggingService.debug(any(), context: any(named: 'context')),
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
          () => mockLoggingService.debug(any(), context: any(named: 'context')),
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

    // Criterion 8 of #60. Redaction used to match the *value* against
    // ['password','token','secret','key','auth']. A real JWT contains none
    // of those, so it fell through to the 100-character truncation and the
    // header plus most of the payload went into the log - under a key the
    // caller had already named `auth_token`.
    group('key-based redaction (#60)', () {
      /// The canonical HS256 example token. Lower-cased it contains none of
      /// the sensitive substrings, which is the whole point.
      const jwt =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
          'eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0Ijox'
          'NTE2MjM5MDIyfQ.'
          'SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';

      Object? loggedValue() {
        final captured = verify(
          () => mockLoggingService.debug(
            any(),
            context: captureAny(named: 'context'),
          ),
        ).captured;
        return (captured.single as Map<String, dynamic>)['value'];
      }

      setUp(() {
        when(
          () => mockLoggingService.debug(any(), context: any(named: 'context')),
        ).thenReturn(null);
      });

      test('redacts a realistic JWT stored under auth_token', () {
        // Guard the premise: the value itself looks innocuous.
        for (final pattern in StorageLoggingMixin.sensitiveKeyPatterns) {
          expect(jwt.toLowerCase().contains(pattern), isFalse);
        }

        storageService.logStorageWrite('setString', 'auth_token', value: jwt);

        final value = loggedValue();
        expect(value, '***REDACTED***');
        expect('$value'.contains('eyJhbGciOi'), isFalse);
      });

      test('redacts a JWT on read as well as write', () {
        storageService.logStorageRead('getString', 'auth_token', value: jwt);

        expect(loggedValue(), '***REDACTED***');
      });

      test('does not redact a harmless value mentioning a pattern', () {
        storageService.logStorageWrite(
          'setString',
          'note',
          value: 'my keyboard password hint is a secret joke',
        );

        expect(loggedValue(), 'my keyboard password hint is a secret joke');
      });

      test('still truncates long non-sensitive values', () {
        final long = 'a' * 150;

        storageService.logStorageWrite('setString', 'note', value: long);

        expect(loggedValue(), '${'a' * 100}... (truncated)');
      });
    });
  });
}
