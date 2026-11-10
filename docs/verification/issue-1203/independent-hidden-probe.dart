import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/logging/uncaught_error_handlers.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
 test('sanitizer makes formerly hidden diagnostic property visible', () {
  final details = FlutterErrorDetails(exception: StateError('ordinary'), informationCollector: () => [StringProperty('hidden value', 'HIDDEN_DIAGNOSTIC_VALUE', level: DiagnosticLevel.hidden)]);
  expect(details.toString(), isNot(contains('HIDDEN_DIAGNOSTIC_VALUE')));
  final saved = FlutterError.onError;
  FlutterErrorDetails? received;
  FlutterError.onError = (details) => received = details;
  final restore = installUncaughtErrorHandlers(LoggingService(enableLogging: false));
  try {
   FlutterError.reportError(details);
   expect(received!.toString(), isNot(contains('HIDDEN_DIAGNOSTIC_VALUE')));
   print('FIX VERIFIED: hidden diagnostic remains absent before and after proxy.');
  } finally { restore(); FlutterError.onError = saved; }
 });
}
