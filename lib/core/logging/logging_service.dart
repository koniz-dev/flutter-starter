import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/logging/log_output.dart';
import 'package:logger/logger.dart';


/// Comprehensive logging service for the application
///
/// This service provides:
/// - Multiple log levels (debug, info, warning, error)
/// - Structured logging with context/metadata
/// - Multiple outputs (console, file, remote)
/// - Integration with error tracking services
/// - Respects ENABLE_LOGGING flag from AppConfig
///
/// Usage:
/// ```dart
/// final logger = ref.read(loggingServiceProvider);
/// logger.debug('Debug message', context: {'key': 'value'});
/// logger.info('Info message');
/// logger.warning('Warning message');
/// logger.error('Error message', error: exception, stackTrace: stackTrace);
/// ```
class LoggingService {
  /// Creates a [LoggingService] instance
  ///
  /// [enableLogging] - Whether logging is enabled (defaults to
  /// AppConfig.enableLogging)
  /// [enableFileLogging] - Whether to log to files (default: true in
  /// production)
  /// [enableRemoteLogging] - Whether to log to remote services
  /// (default: false)
  LoggingService({
    bool? enableLogging,
    bool? enableFileLogging,
    bool? enableRemoteLogging,
  })  : _enableLogging = enableLogging ?? AppConfig.enableLogging,
        _enableFileLogging = enableFileLogging ?? AppConfig.isProduction,
        _enableRemoteLogging = enableRemoteLogging ?? false {
    _initializeLogger();
  }

  /// Whether logging is enabled
  final bool _enableLogging;

  /// Whether file logging is enabled
  final bool _enableFileLogging;

  /// Whether remote logging is enabled
  final bool _enableRemoteLogging;

  /// Internal logger instance
  late final Logger _logger;

  /// File log output instance (if enabled)
  FileLogOutput? _fileOutput;

  /// Initialize the logger with appropriate outputs and formatters
  void _initializeLogger() {
    if (!_enableLogging) {
      // Create a no-op logger if logging is disabled
      _logger = Logger(
        output: _NoOpOutput(),
        printer: _NoOpPrinter(),
      );
      return;
    }

    final outputs = <LogOutput>[];

    // Console output (always enabled in debug mode)
    if (kDebugMode) {
      outputs.add(
        ConsoleOutput(),
      );
    }

    // File output (if enabled)
    if (_enableFileLogging) {
      _fileOutput = FileLogOutput();
      unawaited(_fileOutput!.init());
      outputs.add(_fileOutput!);
    }

    // Remote output (if enabled and configured)
    if (_enableRemoteLogging) {
      // Add remote logging output here
      // Example: outputs.add(RemoteLogOutput(...));
    }

    // Use MultiOutput if multiple outputs are configured
    final output = outputs.length == 1
        ? outputs.first
        : MultiOutput(outputs);

    // Choose printer based on environment
    final printer = AppConfig.isProduction
        ? JsonLogFormatter() // JSON for production
        : PrettyPrinter();

    _logger = Logger(
      printer: printer,
      output: output,
      level: _getLogLevel(),
    );
  }

  /// Get the appropriate log level based on environment
  Level _getLogLevel() {
    if (AppConfig.isProduction) {
      return Level.info; // Only info and above in production
    }
    return Level.debug; // All levels in development
  }

  /// Log a debug message
  ///
  /// [message] - The log message
  /// [context] - Optional context/metadata to include in the log
  void debug(
    String message, {
    Map<String, dynamic>? context,
  }) {
    if (!_enableLogging) return;
    _logger.d(_formatMessage(message, context));
  }

  /// Log an info message
  ///
  /// [message] - The log message
  /// [context] - Optional context/metadata to include in the log
  void info(
    String message, {
    Map<String, dynamic>? context,
  }) {
    if (!_enableLogging) return;
    _logger.i(_formatMessage(message, context));
  }

  /// Log a warning message
  ///
  /// [message] - The log message
  /// [context] - Optional context/metadata to include in the log
  /// [error] - Optional error object
  /// [stackTrace] - Optional stack trace
  void warning(
    String message, {
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_enableLogging) return;
    _logger.w(
      _formatMessage(message, context),
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log an error message
  ///
  /// [message] - The log message
  /// [context] - Optional context/metadata to include in the log
  /// [error] - Optional error object
  /// [stackTrace] - Optional stack trace
  void error(
    String message, {
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_enableLogging) return;
    _logger.e(
      _formatMessage(message, context),
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Format a log message with optional context
  String _formatMessage(
    String message,
    Map<String, dynamic>? context,
  ) {
    if (context == null || context.isEmpty) {
      return message;
    }

    // Format context as JSON for structured logging
    try {
      final contextJson = jsonEncode(context);
      return '$message | Context: $contextJson';
    } on Exception {
      // If JSON encoding fails, fall back to string representation
      return '$message | Context: $context';
    }
  }

  /// Get all log files (if file logging is enabled)
  Future<List<File>> getLogFiles() async {
    if (_fileOutput == null) return [];
    return _fileOutput!.getLogFiles();
  }

  /// Clear all log files (if file logging is enabled)
  Future<void> clearLogs() async {
    if (_fileOutput == null) return;
    await _fileOutput!.clearLogs();
  }

  /// Dispose resources
  void dispose() {
    unawaited(_fileOutput?.destroy());
  }
}

/// No-op output for when logging is disabled
class _NoOpOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // Do nothing
  }
}

/// No-op printer for when logging is disabled
class _NoOpPrinter extends LogPrinter {
  @override
  List<String> log(LogEvent event) {
    return [];
  }
}
