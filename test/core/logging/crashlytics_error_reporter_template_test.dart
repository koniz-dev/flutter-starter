import 'package:flutter_starter/core/logging/crashlytics_error_reporter_template.dart';
import 'package:flutter_starter/core/logging/i_error_reporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CrashlyticsErrorReporter template', () {
    test('is an IErrorReporter, so errorReporterProvider can bind it', () {
      expect(CrashlyticsErrorReporter(), isA<IErrorReporter>());
    });

    test('completes for an error with a stack trace and context', () async {
      await expectLater(
        CrashlyticsErrorReporter().recordError(
          'Operation failed',
          error: StateError('boom'),
          stackTrace: StackTrace.current,
          context: {'id': 1},
        ),
        completes,
      );
    });

    test('completes for a message with no error object', () async {
      await expectLater(
        CrashlyticsErrorReporter().recordError('Operation failed'),
        completes,
      );
    });
  });
}
