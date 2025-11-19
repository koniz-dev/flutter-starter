import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Abstract base class for custom log outputs
///
/// Extend this class to create custom log outputs (e.g., remote logging,
/// Sentry integration, etc.)
abstract class CustomLogOutput extends LogOutput {
  /// Outputs a log entry
  @override
  void output(OutputEvent event) {
    for (final line in event.lines) {
      outputLine(line, event.level);
    }
  }

  /// Outputs a single log line
  ///
  /// Override this method to implement custom output behavior
  void outputLine(String line, Level level);
}

/// File-based log output with rotation support
///
/// This output writes logs to a file and automatically rotates logs
/// when they exceed the maximum file size.
class FileLogOutput extends LogOutput {
  /// Creates a [FileLogOutput] with the given configuration
  ///
  /// [maxFileSize] - Maximum file size in bytes before rotation (default: 10MB)
  /// [maxFiles] - Maximum number of log files to keep (default: 5)
  /// [fileName] - Base name for log files (default: 'app.log')
  FileLogOutput({
    this.maxFileSize = 10 * 1024 * 1024, // 10MB
    this.maxFiles = 5,
    this.fileName = 'app.log',
  });

  /// Maximum file size in bytes before rotation
  final int maxFileSize;

  /// Maximum number of log files to keep
  final int maxFiles;

  /// Base name for log files
  final String fileName;

  File? _logFile;
  IOSink? _sink;
  String? _logDirectory;

  @override
  Future<void> init() async {
    await _initializeLogFile();
  }

  /// Initialize the log file
  Future<void> _initializeLogFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logDirectory = path.join(directory.path, 'logs');

      // Create logs directory if it doesn't exist
      final logDir = Directory(_logDirectory!);
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }

      // Get the current log file
      _logFile = File(path.join(_logDirectory!, fileName));
      _sink = _logFile!.openWrite(mode: FileMode.append);
    } on Exception {
      // If file initialization fails, silently continue without file logging
      // This ensures the app doesn't crash if file system is unavailable
    }
  }

  @override
  void output(OutputEvent event) {
    if (_sink == null) return;

    try {
      event.lines.forEach(_sink!.writeln);
      unawaited(_sink!.flush());

      // Check if rotation is needed
      unawaited(_checkAndRotate());
    } on Exception {
      // Silently handle file write errors
    }
  }

  /// Check if log rotation is needed and perform it
  Future<void> _checkAndRotate() async {
    if (_logFile == null || _logDirectory == null) return;

    try {
      final fileSize = _logFile!.lengthSync();
      if (fileSize >= maxFileSize) {
        await _rotateLogs();
      }
    } on Exception {
      // Silently handle rotation errors
    }
  }

  /// Rotate log files
  Future<void> _rotateLogs() async {
    if (_logDirectory == null) return;

    try {
      // Close current file
      await _sink?.flush();
      await _sink?.close();

      // Rename existing files
      for (var i = maxFiles - 1; i > 0; i--) {
        final oldFile = File(
          path.join(_logDirectory!, '$fileName.$i'),
        );
        final newFile = File(
          path.join(_logDirectory!, '$fileName.${i + 1}'),
        );

        if (oldFile.existsSync()) {
          if (newFile.existsSync()) {
            newFile.deleteSync();
          }
          oldFile.renameSync(newFile.path);
        }
      }

      // Move current log to .1
      final currentLog = File(path.join(_logDirectory!, fileName));
      if (currentLog.existsSync()) {
        final rotatedLog = File(path.join(_logDirectory!, '$fileName.1'));
        if (rotatedLog.existsSync()) {
          rotatedLog.deleteSync();
        }
        currentLog.renameSync(rotatedLog.path);
      }

      // Create new log file
      await _initializeLogFile();
    } on Exception {
      // Silently handle rotation errors
    }
  }

  @override
  Future<void> destroy() async {
    await _sink?.flush();
    await _sink?.close();
  }

  /// Get all log files
  Future<List<File>> getLogFiles() async {
    if (_logDirectory == null) return [];

    try {
      final directory = Directory(_logDirectory!);
      if (!directory.existsSync()) return [];

      final files = directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.contains(fileName))
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      return files;
    } on Exception {
      return [];
    }
  }

  /// Clear all log files
  Future<void> clearLogs() async {
    if (_logDirectory == null) return;

    try {
      final directory = Directory(_logDirectory!);
      if (directory.existsSync()) {
        directory
          ..deleteSync(recursive: true)
          ..createSync(recursive: true);
      }
      await _initializeLogFile();
    } on Exception {
      // Silently handle clear errors
    }
  }
}

/// JSON formatter for production logging
///
/// Formats log entries as JSON for easier parsing in production environments
class JsonLogFormatter extends LogPrinter {
  /// Creates a [JsonLogFormatter]
  JsonLogFormatter();

  @override
  List<String> log(LogEvent event) {
    final json = {
      'timestamp': DateTime.now().toIso8601String(),
      'level': event.level.name,
      'message': event.message,
      'error': event.error?.toString(),
      'stackTrace': event.stackTrace?.toString(),
    };

    return [jsonEncode(json)];
  }
}
