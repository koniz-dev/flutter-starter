/// Sends errors to a crash or error reporting service (Firebase Crashlytics,
/// Sentry, ...).
///
/// `LoggingService.error` forwards every error it logs here, so features keep
/// logging through `loggingServiceProvider` and never call a vendor SDK. Bind
/// an implementation by overriding `errorReporterProvider`; the default,
/// `NoOpErrorReporter`, reports nothing.
///
/// Reporting does not depend on `ENABLE_LOGGING`: that toggle governs log
/// outputs, and which reporter is bound governs reporting.
library;

/// Interface for a crash or error reporting service.
// ignore: one_member_abstracts
abstract class IErrorReporter {
  /// Reports an error logged as [message].
  ///
  /// [error] and [stackTrace] are those passed to `LoggingService.error`, and
  /// [context] its structured context. A failure here, thrown or returned, is
  /// caught by `LoggingService` and never reaches the caller.
  Future<void> recordError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  });
}
