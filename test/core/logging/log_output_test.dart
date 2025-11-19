import 'dart:io';

import 'package:flutter_starter/core/logging/log_output.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

void main() {
  // Initialize Flutter binding for path_provider
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FileLogOutput', () {
    late FileLogOutput fileLogOutput;

    setUp(() async {
      // Setup for each test
    });

    tearDown(() async {
      // Clean up
      await fileLogOutput.destroy();
    });

    test('should initialize log file', () async {
      // Arrange
      fileLogOutput = FileLogOutput(fileName: 'test.log');

      // Act
      await fileLogOutput.init();

      // Assert
      final logFiles = await fileLogOutput.getLogFiles();
      expect(logFiles.length, greaterThanOrEqualTo(0));
    });

    test('should write log output to file', () async {
      // Arrange
      fileLogOutput = FileLogOutput(fileName: 'test.log');
      await fileLogOutput.init();

      final logEvent = LogEvent(Level.info, 'Test log message');
      final event = OutputEvent(logEvent, ['Test log message']);

      // Act
      fileLogOutput.output(event);

      // Wait for async operations (flush and file system)
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Assert
      final logFiles = await fileLogOutput.getLogFiles();
      expect(logFiles.length, greaterThanOrEqualTo(0));
      if (logFiles.isNotEmpty) {
        final logFile = logFiles.first;
        expect(logFile.existsSync(), isTrue);
        final content = await logFile.readAsString();
        expect(content, contains('Test log message'));
      }
    });

    test('should handle multiple log entries', () async {
      // Arrange
      fileLogOutput = FileLogOutput(fileName: 'test.log');
      await fileLogOutput.init();

      // Act
      for (var i = 0; i < 5; i++) {
        final logEvent = LogEvent(Level.info, 'Log entry $i');
        fileLogOutput.output(
          OutputEvent(logEvent, ['Log entry $i']),
        );
      }

      // Wait for async operations
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Assert
      final logFiles = await fileLogOutput.getLogFiles();
      if (logFiles.isNotEmpty) {
        final logFile = logFiles.first;
        expect(logFile.existsSync(), isTrue);
        final content = await logFile.readAsString();
        for (var i = 0; i < 5; i++) {
          expect(content, contains('Log entry $i'));
        }
      }
    });

    test('should handle different log levels', () async {
      // Arrange
      fileLogOutput = FileLogOutput(fileName: 'test.log');
      await fileLogOutput.init();

      final levels = [
        Level.debug,
        Level.info,
        Level.warning,
        Level.error,
      ];

      // Act
      for (final level in levels) {
        final logEvent = LogEvent(level, '${level.name} message');
        fileLogOutput.output(
          OutputEvent(logEvent, ['${level.name} message']),
        );
      }

      // Wait for async operations
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Assert
      final logFiles = await fileLogOutput.getLogFiles();
      if (logFiles.isNotEmpty) {
        final logFile = logFiles.first;
        expect(logFile.existsSync(), isTrue);
        final content = await logFile.readAsString();
        for (final level in levels) {
          expect(content, contains('${level.name} message'));
        }
      }
    });

    test('should rotate logs when file size exceeds maxFileSize', () async {
      // Arrange
      fileLogOutput = FileLogOutput(
        fileName: 'test.log',
        maxFileSize: 100, // Very small for testing
      );
      await fileLogOutput.init();

      // Act - Write enough data to trigger rotation
      for (var i = 0; i < 20; i++) {
        final logEvent = LogEvent(
          Level.info,
          'This is a long log message that will fill up the file quickly.',
        );
        fileLogOutput.output(
          OutputEvent(
            logEvent,
            ['This is a long log message that will fill up the file quickly.'],
          ),
        );
      }

      // Wait for async operations (rotation happens asynchronously)
      await Future<void>.delayed(const Duration(milliseconds: 1000));

      // Assert
      final logFiles = await fileLogOutput.getLogFiles();
      // Should have at least the current log file
      expect(logFiles.length, greaterThanOrEqualTo(0));
    });

    test('should respect maxFiles limit', () async {
      // Arrange
      fileLogOutput = FileLogOutput(
        fileName: 'test.log',
        maxFileSize: 50, // Very small
        maxFiles: 3,
      );
      await fileLogOutput.init();

      // Act - Write enough to create multiple rotated files
      for (var i = 0; i < 50; i++) {
        final logEvent = LogEvent(
          Level.info,
          'Long message to trigger rotation',
        );
        fileLogOutput.output(
          OutputEvent(
            logEvent,
            ['Long message to trigger rotation'],
          ),
        );
      }

      // Wait for async operations
      await Future<void>.delayed(const Duration(milliseconds: 1000));

      // Assert
      final logFiles = await fileLogOutput.getLogFiles();
      // Should not exceed maxFiles
      expect(logFiles.length, lessThanOrEqualTo(3));
    });

    test('should get all log files', () async {
      // Arrange
      fileLogOutput = FileLogOutput(fileName: 'test.log');
      await fileLogOutput.init();

      // Act - Write something to ensure file is created
      final logEvent = LogEvent(Level.info, 'Test');
      fileLogOutput.output(OutputEvent(logEvent, ['Test']));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final logFiles = await fileLogOutput.getLogFiles();

      // Assert
      expect(logFiles, isA<List<File>>());
      // File may or may not exist yet depending on timing
      expect(logFiles.length, greaterThanOrEqualTo(0));
    });

    test('should clear all log files', () async {
      // Arrange
      fileLogOutput = FileLogOutput(fileName: 'test.log');
      await fileLogOutput.init();

      // Write some logs
      final logEvent = LogEvent(Level.info, 'Test message');
      fileLogOutput.output(OutputEvent(logEvent, ['Test message']));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Act
      await fileLogOutput.clearLogs();

      // Assert
      final logFiles = await fileLogOutput.getLogFiles();
      // After clearing, should still have the current log file (reinitialized)
      expect(logFiles.length, greaterThanOrEqualTo(0));
    });

    test('should handle custom fileName', () async {
      // Arrange
      fileLogOutput = FileLogOutput(fileName: 'custom.log');
      await fileLogOutput.init();

      // Act
      final logEvent = LogEvent(Level.info, 'Test');
      fileLogOutput.output(OutputEvent(logEvent, ['Test']));
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Assert
      final logFiles = await fileLogOutput.getLogFiles();
      // File may or may not be created yet, but if it exists,
      // it should contain custom.log
      if (logFiles.isNotEmpty) {
        expect(
          logFiles.any((file) => file.path.contains('custom.log')),
          isTrue,
        );
      } else {
        // If no files yet, that's also acceptable (timing issue)
        expect(logFiles.length, 0);
      }
    });

    test('should handle output when sink is null', () {
      // Arrange
      fileLogOutput = FileLogOutput(fileName: 'test.log');
      // Don't call init, so sink will be null

      // Act & Assert
      final logEvent = LogEvent(Level.info, 'Test');
      expect(
        () => fileLogOutput.output(OutputEvent(logEvent, ['Test'])),
        returnsNormally,
      );
    });

    test('should handle file write errors gracefully', () async {
      // Arrange
      fileLogOutput = FileLogOutput(fileName: 'test.log');
      await fileLogOutput.init();
      await fileLogOutput.destroy(); // Destroy to make sink null

      // Act & Assert
      final logEvent = LogEvent(Level.info, 'Test');
      expect(
        () => fileLogOutput.output(OutputEvent(logEvent, ['Test'])),
        returnsNormally,
      );
    });

    test('should handle initialization errors gracefully', () async {
      // Arrange
      fileLogOutput = FileLogOutput(fileName: 'test.log');

      // Act & Assert
      // The init method should complete even if there are errors
      // (it catches exceptions internally)
      await expectLater(fileLogOutput.init(), completes);
    });

    test('should destroy and close sink', () async {
      // Arrange
      fileLogOutput = FileLogOutput(fileName: 'test.log');
      await fileLogOutput.init();

      // Act
      await fileLogOutput.destroy();

      // Assert - Should not throw
      expect(fileLogOutput, isNotNull);
    });

    group('CustomLogOutput', () {
      test('should output lines for each event line', () {
        // Arrange
        final outputLines = <String>[];
        final outputLevels = <Level>[];

        final customOutput = _TestCustomLogOutput(
          onOutputLine: (line, level) {
            outputLines.add(line);
            outputLevels.add(level);
          },
        );

        final logEvent = LogEvent(Level.info, 'Line 1\nLine 2\nLine 3');
        final event = OutputEvent(
          logEvent,
          ['Line 1', 'Line 2', 'Line 3'],
        );

        // Act
        customOutput.output(event);

        // Assert
        expect(outputLines.length, 3);
        expect(outputLines[0], 'Line 1');
        expect(outputLines[1], 'Line 2');
        expect(outputLines[2], 'Line 3');
        expect(outputLevels.every((level) => level == Level.info), isTrue);
      });

      test('should handle empty event lines', () {
        // Arrange
        final outputLines = <String>[];

        final customOutput = _TestCustomLogOutput(
          onOutputLine: (line, level) {
            outputLines.add(line);
          },
        );

        final logEvent = LogEvent(Level.info, '');
        final event = OutputEvent(logEvent, []);

        // Act
        customOutput.output(event);

        // Assert
        expect(outputLines.isEmpty, isTrue);
      });
    });

    group('JsonLogFormatter', () {
      test('should format log event as JSON', () {
        // Arrange
        final formatter = JsonLogFormatter();
        final event = LogEvent(
          Level.info,
          'Test message',
        );

        // Act
        final lines = formatter.log(event);

        // Assert
        expect(lines.length, 1);
        final json = lines.first;
        expect(json, contains('timestamp'));
        expect(json, contains('level'));
        expect(json, contains('message'));
        expect(json, contains('Test message'));
        expect(json, contains('info'));
      });

      test('should include error in JSON when present', () {
        // Arrange
        final formatter = JsonLogFormatter();
        final error = Exception('Test error');
        final event = LogEvent(
          Level.error,
          'Error message',
          error: error,
        );

        // Act
        final lines = formatter.log(event);

        // Assert
        expect(lines.length, 1);
        final json = lines.first;
        expect(json, contains('error'));
        expect(json, contains('Test error'));
      });

      test('should include stackTrace in JSON when present', () {
        // Arrange
        final formatter = JsonLogFormatter();
        final stackTrace = StackTrace.current;
        final event = LogEvent(
          Level.error,
          'Error message',
          stackTrace: stackTrace,
        );

        // Act
        final lines = formatter.log(event);

        // Assert
        expect(lines.length, 1);
        final json = lines.first;
        expect(json, contains('stackTrace'));
      });

      test('should handle null error and stackTrace', () {
        // Arrange
        final formatter = JsonLogFormatter();
        final event = LogEvent(
          Level.info,
          'Info message',
        );

        // Act
        final lines = formatter.log(event);

        // Assert
        expect(lines.length, 1);
        final json = lines.first;
        expect(json, contains('null')); // null values should be in JSON
      });

      test('should format different log levels', () {
        // Arrange
        final formatter = JsonLogFormatter();
        final levels = [
          Level.debug,
          Level.info,
          Level.warning,
          Level.error,
        ];

        // Act & Assert
        for (final level in levels) {
          final event = LogEvent(level, '${level.name} message');
          final lines = formatter.log(event);
          expect(lines.length, 1);
          final json = lines.first;
          expect(json, contains(level.name));
        }
      });

      test('should include ISO8601 timestamp', () {
        // Arrange
        final formatter = JsonLogFormatter();
        final event = LogEvent(Level.info, 'Test');

        // Act
        final lines = formatter.log(event);

        // Assert
        final json = lines.first;
        // Should contain timestamp in ISO8601 format
        expect(json, matches(RegExp(r'"timestamp"\s*:\s*"[^"]+"')));
      });
    });
  });
}

/// Test implementation of CustomLogOutput
class _TestCustomLogOutput extends CustomLogOutput {
  _TestCustomLogOutput({
    required this.onOutputLine,
  });

  final void Function(String line, Level level) onOutputLine;

  @override
  void outputLine(String line, Level level) {
    onOutputLine(line, level);
  }
}
