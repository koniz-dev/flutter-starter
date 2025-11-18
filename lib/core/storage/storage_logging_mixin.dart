import 'package:flutter_starter/core/logging/logging_service.dart';

/// Mixin for adding logging to storage operations
///
/// This mixin provides logging capabilities for storage service
/// implementations. It logs all storage operations (read, write, delete) with
/// appropriate context.
///
/// Usage:
/// ```dart
/// class MyStorageService with StorageLoggingMixin implements IStorageService {
///   MyStorageService(this.loggingService);
///
///   @override
///   final LoggingService loggingService;
///
///   @override
///   Future<String?> getString(String key) async {
///     _logStorageOperation('getString', key: key);
///     // ... implementation
///   }
/// }
/// ```
mixin StorageLoggingMixin {
  /// Logging service instance (must be provided by implementing class)
  LoggingService get loggingService;

  /// Log a storage read operation
  void logStorageRead(String operation, String key, {dynamic value}) {
    final context = <String, dynamic>{
      'operation': operation,
      'key': key,
      if (value != null) 'value': _sanitizeValue(value),
    };

    loggingService.debug(
      'Storage Read: $operation',
      context: context,
    );
  }

  /// Log a storage write operation
  void logStorageWrite(String operation, String key, {dynamic value}) {
    final context = <String, dynamic>{
      'operation': operation,
      'key': key,
      if (value != null) 'value': _sanitizeValue(value),
    };

    loggingService.debug(
      'Storage Write: $operation',
      context: context,
    );
  }

  /// Log a storage delete operation
  void logStorageDelete(String operation, String key) {
    final context = <String, dynamic>{
      'operation': operation,
      'key': key,
    };

    loggingService.debug(
      'Storage Delete: $operation',
      context: context,
    );
  }

  /// Log a storage error
  void logStorageError(
    String operation,
    String key,
    Object error, {
    StackTrace? stackTrace,
  }) {
    final context = <String, dynamic>{
      'operation': operation,
      'key': key,
    };

    loggingService.error(
      'Storage Error: $operation',
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Sanitize sensitive values before logging
  dynamic _sanitizeValue(dynamic value) {
    if (value == null) return null;

    final valueString = value.toString().toLowerCase();
    const sensitivePatterns = [
      'password',
      'token',
      'secret',
      'key',
      'auth',
    ];

    final isSensitive = sensitivePatterns.any(valueString.contains);

    if (isSensitive) {
      return '***REDACTED***';
    }

    // Limit value length for logging
    if (value is String && value.length > 100) {
      return '${value.substring(0, 100)}... (truncated)';
    }

    return value;
  }
}
