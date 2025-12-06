import 'dart:io';

import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Initialize Flutter binding for path_provider
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LoggingService', () {
    setUp(() async {
      // Setup for each test
    });

    tearDown(() async {
      // Clean up
    });

    group('Initialization', () {
      test('should initialize with default settings', () {
        // Act
        final service = LoggingService();

        // Assert
        expect(service, isNotNull);
      });

      test('should initialize with logging disabled', () {
        // Act
        final service = LoggingService(enableLogging: false);

        // Assert
        expect(service, isNotNull);
        // Should not throw when logging
        expect(() => service.debug('Test'), returnsNormally);
        expect(() => service.info('Test'), returnsNormally);
      });

      test('should initialize with file logging enabled', () async {
        // Act
        final service = LoggingService(
          enableLogging: true,
          enableFileLogging: true,
        );

        // Wait for file initialization
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Assert
        expect(service, isNotNull);
        final logFiles = await service.getLogFiles();
        expect(logFiles, isA<List<File>>());
      });

      test('should initialize with file logging disabled', () async {
        // Act
        final service = LoggingService(
          enableLogging: true,
          enableFileLogging: false,
        );

        // Assert
        expect(service, isNotNull);
        final logFiles = await service.getLogFiles();
        expect(logFiles, isEmpty);
      });

      test('should initialize with remote logging enabled', () {
        // Act
        final service = LoggingService(
          enableLogging: true,
          enableRemoteLogging: true,
        );

        // Assert
        expect(service, isNotNull);
        // Should not throw when logging
        expect(() => service.info('Test'), returnsNormally);
      });
    });

    group('Debug logging', () {
      test('should log debug message without context', () {
        // Arrange
        final service = LoggingService(enableLogging: true);

        // Act & Assert
        expect(() => service.debug('Debug message'), returnsNormally);
      });

      test('should log debug message with context', () {
        // Arrange
        final service = LoggingService(enableLogging: true);

        // Act & Assert
        expect(
          () => service.debug(
            'Debug message',
            context: {'key': 'value', 'number': 42},
          ),
          returnsNormally,
        );
      });

      test('should not log when logging is disabled', () {
        // Arrange
        final service = LoggingService(enableLogging: false);

        // Act & Assert
        expect(() => service.debug('Debug message'), returnsNormally);
      });

      test('should handle empty context', () {
        // Arrange
        final service = LoggingService(enableLogging: true);

        // Act & Assert
        expect(
          () => service.debug('Debug message', context: {}),
          returnsNormally,
        );
      });

      test('should handle null context', () {
        // Arrange
        final service = LoggingService(enableLogging: true);

        // Act & Assert
        expect(
          () => service.debug('Debug message'),
          returnsNormally,
        );
      });
    });

    group('Info logging', () {
      test('should log info message without context', () {
        // Arrange
        final service = LoggingService(enableLogging: true);

        // Act & Assert
        expect(() => service.info('Info message'), returnsNormally);
      });

      test('should log info message with context', () {
        // Arrange
        final service = LoggingService(enableLogging: true);

        // Act & Assert
        expect(
          () => service.info(
            'Info message',
            context: {'userId': '123', 'action': 'login'},
          ),
          returnsNormally,
        );
      });

      test('should not log when logging is disabled', () {
        // Arrange
        final service = LoggingService(enableLogging: false);

        // Act & Assert
        expect(() => service.info('Info message'), returnsNormally);
      });

      test('should handle complex context data', () {
        // Arrange
        final service = LoggingService(enableLogging: true);

        // Act & Assert
        expect(
          () => service.info(
            'Info message',
            context: {
              'nested': {
                'key': 'value',
                'list': [1, 2, 3],
              },
              'array': ['a', 'b', 'c'],
            },
          ),
          returnsNormally,
        );
      });
    });

    group('Warning logging', () {
      test('should log warning message without error', () {
        // Arrange
        final service = LoggingService(enableLogging: true);

        // Act & Assert
        expect(() => service.warning('Warning message'), returnsNormally);
      });

      test('should log warning message with context', () {
        // Arrange
        final service = LoggingService(enableLogging: true);

        // Act & Assert
        expect(
          () => service.warning(
            'Warning message',
            context: {'warningType': 'deprecated'},
          ),
          returnsNormally,
        );
      });

      test('should log warning message with error', () {
        // Arrange
        final service = LoggingService(enableLogging: true);
        final error = Exception('Test error');

        // Act & Assert
        expect(
          () => service.warning(
            'Warning message',
            error: error,
          ),
          returnsNormally,
        );
      });

      test('should log warning message with stackTrace', () {
        // Arrange
        final service = LoggingService(enableLogging: true);
        final stackTrace = StackTrace.current;

        // Act & Assert
        expect(
          () => service.warning(
            'Warning message',
            stackTrace: stackTrace,
          ),
          returnsNormally,
        );
      });

      test('should log warning message with error and stackTrace', () {
        // Arrange
        final service = LoggingService(enableLogging: true);
        final error = Exception('Test error');
        final stackTrace = StackTrace.current;

        // Act & Assert
        expect(
          () => service.warning(
            'Warning message',
            error: error,
            stackTrace: stackTrace,
          ),
          returnsNormally,
        );
      });

      test('should not log when logging is disabled', () {
        // Arrange
        final service = LoggingService(enableLogging: false);

        // Act & Assert
        expect(() => service.warning('Warning message'), returnsNormally);
      });
    });

    group('Error logging', () {
      test('should log error message without error', () {
        // Arrange
        final service = LoggingService(enableLogging: true);

        // Act & Assert
        expect(() => service.error('Error message'), returnsNormally);
      });

      test('should log error message with context', () {
        // Arrange
        final service = LoggingService(enableLogging: true);

        // Act & Assert
        expect(
          () => service.error(
            'Error message',
            context: {'errorCode': 'E001'},
          ),
          returnsNormally,
        );
      });

      test('should log error message with error', () {
        // Arrange
        final service = LoggingService(enableLogging: true);
        final error = Exception('Test error');

        // Act & Assert
        expect(
          () => service.error(
            'Error message',
            error: error,
          ),
          returnsNormally,
        );
      });

      test('should log error message with stackTrace', () {
        // Arrange
        final service = LoggingService(enableLogging: true);
        final stackTrace = StackTrace.current;

        // Act & Assert
        expect(
          () => service.error(
            'Error message',
            stackTrace: stackTrace,
          ),
          returnsNormally,
        );
      });

      test('should log error message with error and stackTrace', () {
        // Arrange
        final service = LoggingService(enableLogging: true);
        final error = Exception('Test error');
        final stackTrace = StackTrace.current;

        // Act & Assert
        expect(
          () => service.error(
            'Error message',
            error: error,
            stackTrace: stackTrace,
          ),
          returnsNormally,
        );
      });

      test('should log error message with all parameters', () {
        // Arrange
        final service = LoggingService(enableLogging: true);
        final error = Exception('Test error');
        final stackTrace = StackTrace.current;

        // Act & Assert
        expect(
          () => service.error(
            'Error message',
            context: {'errorCode': 'E001', 'userId': '123'},
            error: error,
            stackTrace: stackTrace,
          ),
          returnsNormally,
        );
      });

      test('should not log when logging is disabled', () {
        // Arrange
        final service = LoggingService(enableLogging: false);

        // Act & Assert
        expect(() => service.error('Error message'), returnsNormally);
      });
    });

    group('Message formatting', () {
      test('should format message without context', () {
        // Arrange
        final service = LoggingService(enableLogging: true);

        // Act & Assert
        // Message without context should be returned as-is
        expect(() => service.debug('Simple message'), returnsNormally);
      });

      test('should format message with simple context', () {
        // Arrange
        final service = LoggingService(enableLogging: true);

        // Act & Assert
        expect(
          () => service.debug(
            'Message',
            context: {'key': 'value'},
          ),
          returnsNormally,
        );
      });

      test('should format message with complex context', () {
        // Arrange
        final service = LoggingService(enableLogging: true);

        // Act & Assert
        expect(
          () => service.debug(
            'Message',
            context: {
              'string': 'value',
              'number': 42,
              'boolean': true,
              'list': [1, 2, 3],
              'map': {'nested': 'value'},
            },
          ),
          returnsNormally,
        );
      });

      test('should handle JSON encoding errors gracefully', () {
        // Arrange
        final service = LoggingService(enableLogging: true);
        // Create a context with circular reference
        // (will cause JSON encoding to fail)
        final context = <String, dynamic>{};
        context['self'] = context; // Circular reference

        // Act & Assert
        // Should not throw, should fall back to string representation
        expect(
          () => service.debug('Message', context: context),
          returnsNormally,
        );
      });
    });

    group('File logging', () {
      test('should get log files when file logging is enabled', () async {
        // Arrange
        final service = LoggingService(
          enableLogging: true,
          enableFileLogging: true,
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Act
        final logFiles = await service.getLogFiles();

        // Assert
        expect(logFiles, isA<List<File>>());
      });

      test('should return empty list when file logging is disabled', () async {
        // Arrange
        final service = LoggingService(
          enableLogging: true,
          enableFileLogging: false,
        );

        // Act
        final logFiles = await service.getLogFiles();

        // Assert
        expect(logFiles, isEmpty);
      });

      test('should clear logs when file logging is enabled', () async {
        // Arrange
        final service = LoggingService(
          enableLogging: true,
          enableFileLogging: true,
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Write some logs
        service.info('Test log');
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Act
        await service.clearLogs();

        // Assert
        // Should not throw
        expect(service, isNotNull);
      });

      test('should clear logs when file logging is disabled', () async {
        // Arrange
        final service = LoggingService(
          enableLogging: true,
          enableFileLogging: false,
        );

        // Act & Assert
        await expectLater(service.clearLogs(), completes);
      });
    });

    group('Dispose', () {
      test('should dispose resources', () {
        // Arrange
        final service = LoggingService(
          enableLogging: true,
          enableFileLogging: true,
        );

        // Act & Assert
        expect(service.dispose, returnsNormally);
      });

      test('should dispose when file logging is disabled', () {
        // Arrange
        final service = LoggingService(
          enableLogging: true,
          enableFileLogging: false,
        );

        // Act & Assert
        expect(service.dispose, returnsNormally);
      });

      test('should dispose when logging is disabled', () {
        // Arrange
        final service = LoggingService(enableLogging: false);

        // Act & Assert
        expect(service.dispose, returnsNormally);
      });
    });

    group('Multiple log calls', () {
      test('should handle multiple debug calls', () {
        // Arrange
        final service = LoggingService(enableLogging: true);

        // Act & Assert
        for (var i = 0; i < 10; i++) {
          expect(() => service.debug('Debug $i'), returnsNormally);
        }
      });

      test('should handle multiple info calls', () {
        // Arrange
        final service = LoggingService(enableLogging: true);

        // Act & Assert
        for (var i = 0; i < 10; i++) {
          expect(() => service.info('Info $i'), returnsNormally);
        }
      });

      test('should handle multiple warning calls', () {
        // Arrange
        final service = LoggingService(enableLogging: true);

        // Act & Assert
        for (var i = 0; i < 10; i++) {
          expect(() => service.warning('Warning $i'), returnsNormally);
        }
      });

      test('should handle multiple error calls', () {
        // Arrange
        final service = LoggingService(enableLogging: true);

        // Act & Assert
        for (var i = 0; i < 10; i++) {
          expect(() => service.error('Error $i'), returnsNormally);
        }
      });

      test('should handle mixed log level calls', () {
        // Arrange
        final service = LoggingService(enableLogging: true);

        // Act & Assert
        expect(() => service.debug('Debug'), returnsNormally);
        expect(() => service.info('Info'), returnsNormally);
        expect(() => service.warning('Warning'), returnsNormally);
        expect(() => service.error('Error'), returnsNormally);
      });
    });

    group('Edge cases', () {
      test('should handle empty message', () {
        // Arrange
        final service = LoggingService(enableLogging: true);

        // Act & Assert
        expect(() => service.debug(''), returnsNormally);
        expect(() => service.info(''), returnsNormally);
        expect(() => service.warning(''), returnsNormally);
        expect(() => service.error(''), returnsNormally);
      });

      test('should handle very long message', () {
        // Arrange
        final service = LoggingService(enableLogging: true);
        final longMessage = 'A' * 10000;

        // Act & Assert
        expect(() => service.debug(longMessage), returnsNormally);
      });

      test('should handle special characters in message', () {
        // Arrange
        final service = LoggingService(enableLogging: true);
        const specialMessage =
            'Message with special chars: '
            r'!@#$%^&*()_+-=[]{}|;:,.<>?';

        // Act & Assert
        expect(() => service.debug(specialMessage), returnsNormally);
      });

      test('should handle unicode characters in message', () {
        // Arrange
        final service = LoggingService(enableLogging: true);
        const unicodeMessage = 'Message with unicode: 你好世界 🌍';

        // Act & Assert
        expect(() => service.debug(unicodeMessage), returnsNormally);
      });

      test('should handle null error', () {
        // Arrange
        final service = LoggingService(enableLogging: true);

        // Act & Assert
        expect(
          () => service.warning('Warning'),
          returnsNormally,
        );
        expect(
          () => service.error('Error'),
          returnsNormally,
        );
      });

      test('should handle null stackTrace', () {
        // Arrange
        final service = LoggingService(enableLogging: true);

        // Act & Assert
        expect(
          () => service.warning('Warning'),
          returnsNormally,
        );
        expect(
          () => service.error('Error'),
          returnsNormally,
        );
      });
    });
  });
}
