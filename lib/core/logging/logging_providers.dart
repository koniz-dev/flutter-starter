import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_starter/core/logging/error_reporter_providers.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';

/// Provider for [LoggingService] instance
///
/// This provider creates a singleton instance of [LoggingService] that can be
/// used throughout the application for logging operations.
///
/// The service respects the ENABLE_LOGGING flag from AppConfig and provides
/// different outputs based on the environment (console for development, file
/// for production). Every error it logs is also forwarded to the reporter bound
/// to `errorReporterProvider`.
///
/// Usage:
/// ```dart
/// final logger = ref.read(loggingServiceProvider);
/// logger.info('Application started');
/// ```
final loggingServiceProvider = Provider<LoggingService>((ref) {
  final service = LoggingService(
    errorReporter: ref.watch(errorReporterProvider),
  );

  // Dispose the service when the provider is disposed
  ref.onDispose(service.dispose);

  return service;
});
