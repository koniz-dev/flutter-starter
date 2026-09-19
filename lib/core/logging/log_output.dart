import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
///
/// ## Lines emitted while no sink is open
///
/// [init] is asynchronous and rotation closes the sink for a moment, so
/// there are two windows in which there is no file to write to. Lines
/// emitted in either window are held in a bounded in-memory buffer and
/// written as soon as a sink is open again, rather than being dropped. The
/// first window is app startup, which is exactly when a startup-crash
/// investigation needs the logs.
class FileLogOutput extends LogOutput {
  /// Creates a [FileLogOutput] with the given configuration
  ///
  /// [maxFileSize] - Maximum file size in bytes before rotation (default: 10MB)
  /// [maxFiles] - Maximum number of log files to keep (default: 5)
  /// [fileName] - Base name for log files (default: 'app.log')
  /// [maxPendingLines] - Maximum number of lines held while no sink is open
  /// (default: 1000). Oldest lines are discarded first once the buffer is
  /// full, so a device that can never open a log file cannot grow this
  /// without bound.
  FileLogOutput({
    this.maxFileSize = 10 * 1024 * 1024, // 10MB
    this.maxFiles = 5,
    this.fileName = 'app.log',
    this.maxPendingLines = 1000,
  });

  /// Maximum file size in bytes before rotation
  final int maxFileSize;

  /// Maximum number of log files to keep
  final int maxFiles;

  /// Base name for log files
  final String fileName;

  /// Maximum number of lines buffered while no sink is open
  final int maxPendingLines;

  File? _logFile;
  IOSink? _sink;
  String? _logDirectory;

  /// Lines emitted before [init] completed, or during a rotation.
  final List<String> _pendingLines = <String>[];

  /// True while [_rotateLogs] is between closing one sink and opening the
  /// next. Guards against two concurrent rotations, which would rename the
  /// generations twice and discard one.
  bool _isRotating = false;

  /// The flush currently in progress, if any.
  ///
  /// An [IOSink] binds itself for the duration of a `flush()`, so **any**
  /// write while a flush is outstanding throws
  /// `StateError('StreamSink is bound to a stream')`. `StateError` is an
  /// Error, not an Exception, so the old `on Exception` handler did not
  /// catch it: flushing on every log line meant the next log line threw
  /// that Error out of the logging call. Writes that arrive during a flush
  /// go to [_pendingLines] and are written when it settles.
  Future<void>? _flushInFlight;

  /// Number of lines currently buffered because no sink is open.
  ///
  /// Exposed for tests and diagnostics.
  int get pendingLineCount => _pendingLines.length;

  /// The sink currently being written to, or null if none is open.
  ///
  /// Only for tests: `IOSink.done` is the one observable signal that a sink
  /// was actually closed rather than abandoned.
  @visibleForTesting
  IOSink? get debugSink => _sink;

  /// Force a rotation, for tests that need to drive the concurrency guard.
  @visibleForTesting
  Future<void> debugRotate() => _rotateLogs();

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
      _flushPending();
    } on Object {
      // If file initialization fails, silently continue without file logging.
      // This ensures the app doesn't crash if the file system is unavailable.
      // Caught as Object rather than Exception because a missing plugin or a
      // closed sink surfaces as an Error, not an Exception.
    }
  }

  /// Buffer [lines] until a sink is available, dropping the oldest first.
  void _buffer(List<String> lines) {
    _pendingLines.addAll(lines);
    if (_pendingLines.length > maxPendingLines) {
      _pendingLines.removeRange(0, _pendingLines.length - maxPendingLines);
    }
  }

  /// Write anything buffered to the current sink.
  void _flushPending() {
    final sink = _sink;
    if (sink == null || _flushInFlight != null || _pendingLines.isEmpty) {
      return;
    }
    final pending = List<String>.of(_pendingLines);
    _pendingLines.clear();
    if (!_writeTo(sink, pending)) return;
    _scheduleFlush();
  }

  /// Write [lines] to [sink], returning false if the write failed.
  bool _writeTo(IOSink sink, List<String> lines) {
    try {
      lines.forEach(sink.writeln);
      return true;
    } on Object {
      // Silently handle file write errors. Caught as Object because writing
      // to a closed or bound IOSink throws StateError, which is an Error and
      // would otherwise propagate out of the logging call into the code it
      // was meant to observe.
      return false;
    }
  }

  @override
  void output(OutputEvent event) {
    final sink = _sink;
    if (sink == null || _isRotating || _flushInFlight != null) {
      // No file to write to right now: no sink yet, a rotation in progress,
      // or a flush holding the sink bound. Hold the lines instead of
      // dropping them, and never let that state throw into the caller.
      _buffer(event.lines);
      return;
    }

    if (!_writeTo(sink, event.lines)) return;
    _scheduleFlush();
  }

  /// Start a flush if none is in progress.
  void _scheduleFlush() {
    if (_flushInFlight != null) return;
    final sink = _sink;
    if (sink == null) return;
    _flushInFlight = _flushThenMaybeRotate(sink);
  }

  Future<void> _flushThenMaybeRotate(IOSink sink) async {
    try {
      await sink.flush();
    } on Object {
      // A closed or failing sink must not propagate out of a log call.
    }
    _flushInFlight = null;

    // Lines that arrived while the sink was bound went to the buffer.
    _flushPending();

    // Only check the size once the bytes are actually on disk; checking
    // before the flush settled read a stale length, so rotation never fired.
    await _checkAndRotate();
  }

  /// Wait for any in-flight flush to settle, write anything still buffered,
  /// then close [sink].
  Future<void> _closeSink(IOSink? sink) async {
    final inFlight = _flushInFlight;
    _flushInFlight = null;
    if (inFlight != null) {
      try {
        await inFlight;
      } on Object {
        // Nothing to do; the sink is being discarded.
      }
      _flushInFlight = null;
    }
    if (sink != null && _pendingLines.isNotEmpty) {
      final pending = List<String>.of(_pendingLines);
      _pendingLines.clear();
      _writeTo(sink, pending);
    }
    try {
      // close() flushes what is left before closing.
      await sink?.close();
    } on Object {
      // Nothing to do; the sink is being discarded.
    }
  }

  /// Check if log rotation is needed and perform it
  Future<void> _checkAndRotate() async {
    if (_isRotating) return;
    if (_logFile == null || _logDirectory == null) return;

    try {
      final fileSize = _logFile!.lengthSync();
      if (fileSize >= maxFileSize) {
        await _rotateLogs();
      }
    } on Object {
      // Silently handle rotation errors
    }
  }

  /// Rotate log files
  Future<void> _rotateLogs() async {
    if (_logDirectory == null) return;
    // Set synchronously, before the first await, so two callers cannot both
    // get past the guard in _checkAndRotate and rotate the same generation
    // twice.
    if (_isRotating) return;
    _isRotating = true;

    try {
      // Close current file
      final sink = _sink;
      _sink = null;
      await _closeSink(sink);

      // Rename existing files
      for (var i = maxFiles - 1; i > 0; i--) {
        final oldFile = File(path.join(_logDirectory!, '$fileName.$i'));
        final newFile = File(path.join(_logDirectory!, '$fileName.${i + 1}'));

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
    } on Object {
      // Silently handle rotation errors
    } finally {
      _isRotating = false;
      // Create the new log file and drain anything buffered during the
      // rotation window. Done after clearing _isRotating so _flushPending
      // can write.
      await _initializeLogFile();
    }
  }

  @override
  Future<void> destroy() async {
    final sink = _sink;
    _sink = null;
    await _closeSink(sink);
  }

  /// Get all log files
  Future<List<File>> getLogFiles() async {
    if (_logDirectory == null) return [];

    try {
      final directory = Directory(_logDirectory!);
      if (!directory.existsSync()) return [];

      final files =
          directory
              .listSync()
              .whereType<File>()
              .where((file) => file.path.contains(fileName))
              .toList()
            ..sort(
              (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
            );

      return files;
    } on Object {
      return [];
    }
  }

  /// Clear all log files
  ///
  /// Closes the current sink before deleting the directory it writes into.
  /// Omitting that leaked one file descriptor per call.
  Future<void> clearLogs() async {
    if (_logDirectory == null) return;

    final sink = _sink;
    _sink = null;
    await _closeSink(sink);

    // Anything buffered belongs to the logs being cleared.
    _pendingLines.clear();

    try {
      final directory = Directory(_logDirectory!);
      if (directory.existsSync()) {
        directory
          ..deleteSync(recursive: true)
          ..createSync(recursive: true);
      }
      await _initializeLogFile();
    } on Object {
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
      // UTC, so the string always carries the `Z` designator. A local
      // DateTime's toIso8601String() has no offset at all, and every log
      // aggregator reads an offset-less ISO-8601 string as UTC - which puts
      // a UTC+7 device's logs seven hours in the future.
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'level': event.level.name,
      'message': event.message,
      'error': event.error?.toString(),
      'stackTrace': event.stackTrace?.toString(),
    };

    return [jsonEncode(json)];
  }
}
