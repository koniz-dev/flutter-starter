import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/logging/error_reporter_providers.dart';
import 'package:flutter_starter/core/logging/i_error_reporter.dart';
import 'package:flutter_starter/core/logging/logging_providers.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/logging/noop_error_reporter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

/// One [IErrorReporter.recordError] call.
typedef _Report = ({
  String message,
  Object? error,
  StackTrace? stackTrace,
  Map<String, dynamic>? context,
});

class _RecordingReporter implements IErrorReporter {
  final reports = <_Report>[];

  @override
  Future<void> recordError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) async {
    reports.add((
      message: message,
      error: error,
      stackTrace: stackTrace,
      context: context,
    ));
  }
}

/// Throws before returning a future, as a careless adapter might.
class _ThrowingReporter implements IErrorReporter {
  @override
  Future<void> recordError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) => throw StateError('reporter is down');
}

/// Returns a future that fails, as an SDK call over the network might.
class _FailingReporter implements IErrorReporter {
  @override
  Future<void> recordError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) => Future.error(StateError('upload failed'));
}

class _RecordingOutput extends LogOutput {
  final events = <OutputEvent>[];

  @override
  void output(OutputEvent event) => events.add(event);
}

void main() {
  group('errorReporterProvider', () {
    test('defaults to NoOpErrorReporter, which completes', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final reporter = container.read(errorReporterProvider);

      expect(reporter, isA<NoOpErrorReporter>());
      await expectLater(reporter.recordError('anything'), completes);
    });

    test('an override reaches LoggingService.error, and only error', () async {
      final reporter = _RecordingReporter();
      final container = ProviderContainer(
        overrides: [errorReporterProvider.overrideWithValue(reporter)],
      );
      addTearDown(container.dispose);
      final logger = container.read(loggingServiceProvider);
      final error = StateError('boom');
      final trace = StackTrace.current;

      logger
        ..debug('d')
        ..info('i')
        ..warning('w', error: StateError('not an error log'))
        ..error(
          'Operation failed',
          error: error,
          stackTrace: trace,
          context: {'id': 7},
        );
      await pumpEventQueue();

      expect(reporter.reports, hasLength(1));
      final report = reporter.reports.single;
      expect(report.message, 'Operation failed');
      expect(report.error, same(error));
      expect(report.stackTrace, same(trace));
      expect(report.context, {'id': 7});
    });
  });

  group('LoggingService forwarding', () {
    test('still reports when logging is disabled', () async {
      final reporter = _RecordingReporter();
      final output = _RecordingOutput();

      LoggingService(
        enableLogging: false,
        errorReporter: reporter,
        output: output,
      ).error('Operation failed', error: StateError('boom'));
      await pumpEventQueue();

      expect(output.events, isEmpty, reason: 'nothing is logged');
      expect(reporter.reports.single.message, 'Operation failed');
    });

    test('a reporter that throws does not break the log call', () async {
      final output = _RecordingOutput();
      final logger = LoggingService(
        enableLogging: true,
        errorReporter: _ThrowingReporter(),
        output: output,
      );

      expect(() => logger.error('Operation failed'), returnsNormally);
      await pumpEventQueue();

      expect(output.events.map((e) => e.level), [Level.error, Level.warning]);
      expect(output.events.last.origin.message, 'Error reporter failed');
      expect(output.events.last.origin.error, isA<StateError>());
    });

    test('a reporter whose future fails does not surface the error', () async {
      final output = _RecordingOutput();

      // An unhandled async error would fail this test from the zone.
      LoggingService(
        enableLogging: true,
        errorReporter: _FailingReporter(),
        output: output,
      ).error('Operation failed');
      await pumpEventQueue();

      expect(output.events.map((e) => e.level), [Level.error, Level.warning]);
      expect(
        (output.events.last.origin.error! as StateError).message,
        'upload failed',
      );
    });

    test('defaults to the no-op reporter when none is given', () {
      expect(
        () => LoggingService(
          enableLogging: true,
          output: _RecordingOutput(),
        ).error('Operation failed'),
        returnsNormally,
      );
    });
  });
}
