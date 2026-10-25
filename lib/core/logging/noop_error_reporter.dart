import 'package:flutter_starter/core/logging/i_error_reporter.dart';

/// Default no-op implementation for [IErrorReporter].
///
/// This allows the app to run without any crash reporting vendor integration.
class NoOpErrorReporter implements IErrorReporter {
  /// Creates a reporter that reports nothing.
  const NoOpErrorReporter();

  @override
  Future<void> recordError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) async {}
}
