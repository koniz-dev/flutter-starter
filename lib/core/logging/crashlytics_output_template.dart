// TEMPLATE: Not wired into the default logging pipeline; opt in via docs.
import 'package:logger/logger.dart';

// IMPORTANT: To enable Firebase Crashlytics logging:
// 1. Run: flutter pub add firebase_crashlytics
// 2. Uncomment the import below
// import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// An optional Firebase Crashlytics Log Output template.
///
/// Use this inside `lib/core/logging/logging_service.dart`:
/// ```dart
/// if (_enableRemoteLogging) {
///   outputs.add(CrashlyticsOutput());
/// }
/// ```
class CrashlyticsOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // Only send WARNING or ERROR logs to Crashlytics
    if (event.level == Level.error || event.level == Level.warning) {
      // Uncomment the code below to fully send logs to crashlytics:

      /*
      final isFatal = event.level == Level.error;
      final message = event.lines.join('\n');

      FirebaseCrashlytics.instance.recordError(
        message, // You can extract actual error object if needed
        null, // stackTrace
        reason: message,
        fatal: isFatal,
      );
      */
    }
  }
}
