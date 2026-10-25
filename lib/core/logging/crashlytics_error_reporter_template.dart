// TEMPLATE: Not bound by default; opt in by overriding errorReporterProvider.
import 'package:flutter_starter/core/logging/i_error_reporter.dart';

// IMPORTANT: To report errors to Firebase Crashlytics:
// 1. Run: flutter pub add firebase_crashlytics, and initialise Firebase.
// 2. Uncomment the import below and the body of recordError.
// 3. Bind it where the app container is built:
//      errorReporterProvider.overrideWithValue(CrashlyticsErrorReporter()),
// import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// An optional Firebase Crashlytics [IErrorReporter] template.
///
/// `LoggingService.error` forwards every error it logs to the bound reporter,
/// so this receives the real error object and stack trace rather than the
/// formatted log lines. Sentry or any other service follows the same shape:
/// implement [IErrorReporter] and override `errorReporterProvider`.
class CrashlyticsErrorReporter implements IErrorReporter {
  @override
  Future<void> recordError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) async {
    // Uncomment the code below to send errors to Crashlytics:

    /*
    final crashlytics = FirebaseCrashlytics.instance;
    for (final entry in (context ?? const <String, dynamic>{}).entries) {
      await crashlytics.setCustomKey(entry.key, entry.value.toString());
    }
    await crashlytics.recordError(
      error ?? message,
      stackTrace,
      reason: message,
    );
    */
  }
}
