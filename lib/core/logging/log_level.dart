/// Log levels for the logging service
///
/// These levels follow the standard logging hierarchy:
/// - [LogLevel.debug]: Detailed information for debugging
/// - [LogLevel.info]: General informational messages
/// - [LogLevel.warning]: Warning messages for potential issues
/// - [LogLevel.error]: Error messages for failures
enum LogLevel {
  /// Debug level - detailed information for debugging
  debug,

  /// Info level - general informational messages
  info,

  /// Warning level - warning messages for potential issues
  warning,

  /// Error level - error messages for failures
  error,
}

/// Extension methods for [LogLevel]
extension LogLevelExtension on LogLevel {
  /// Returns the string representation of the log level
  String get name {
    switch (this) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARNING';
      case LogLevel.error:
        return 'ERROR';
    }
  }

  /// Returns the numeric value for sorting/ordering
  int get value {
    switch (this) {
      case LogLevel.debug:
        return 0;
      case LogLevel.info:
        return 1;
      case LogLevel.warning:
        return 2;
      case LogLevel.error:
        return 3;
    }
  }
}
