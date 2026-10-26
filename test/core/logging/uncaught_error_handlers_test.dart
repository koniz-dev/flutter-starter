import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/logging/error_reporter_providers.dart';
import 'package:flutter_starter/core/logging/i_error_reporter.dart';
import 'package:flutter_starter/core/logging/logging_providers.dart';
import 'package:flutter_starter/core/logging/uncaught_error_handlers.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingReporter implements IErrorReporter {
  final reports = <({String message, Object? error, StackTrace? stack})>[];

  @override
  Future<void> recordError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) async {
    reports.add((message: message, error: error, stack: stackTrace));
  }
}

class _ThrowsInBuild extends StatelessWidget {
  const _ThrowsInBuild();

  @override
  Widget build(BuildContext context) => throw StateError('build failed');
}

void main() {
  late _RecordingReporter reporter;
  late ProviderContainer container;

  setUp(() {
    reporter = _RecordingReporter();
    container = ProviderContainer(
      overrides: [errorReporterProvider.overrideWithValue(reporter)],
    );
    addTearDown(container.dispose);
  });

  testWidgets('an uncaught framework error is reported once, with its stack, '
      'and still reaches the previous handler', (tester) async {
    final restore = installUncaughtErrorHandlers(
      container.read(loggingServiceProvider),
    );
    addTearDown(restore);

    await tester.pumpWidget(const _ThrowsInBuild());
    // The previous handler (the test binding's) still received it.
    expect(tester.takeException(), isA<StateError>());
    await tester.pump();

    expect(reporter.reports, hasLength(1));
    final report = reporter.reports.single;
    expect(report.message, 'Uncaught Flutter error');
    expect(report.error, isA<StateError>());
    expect(report.stack, isNotNull);
    expect(report.stack.toString(), contains('_ThrowsInBuild.build'));
  });

  test('an async error that escaped every zone is reported once, with its '
      'stack, and marked handled', () async {
    final dispatcher = PlatformDispatcher.instance;
    final previousCalls = <Object>[];
    final saved = dispatcher.onError;
    dispatcher.onError = (error, stack) {
      previousCalls.add(error);
      return false;
    };
    addTearDown(() => dispatcher.onError = saved);

    final restore = installUncaughtErrorHandlers(
      container.read(loggingServiceProvider),
    );
    addTearDown(restore);
    final installed = dispatcher.onError!;
    bool? handled;
    dispatcher.onError = (error, stack) => handled = installed(error, stack);

    // A failing Future nobody awaits, in the root zone: flutter_test's own
    // zone never sees it, and the engine hands it to PlatformDispatcher
    // .onError, as it would in the app.
    final error = StateError('async failure');
    final stack = StackTrace.current;
    Zone.root.run(() => unawaited(Future<void>.error(error, stack)));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(handled, isTrue);
    expect(previousCalls, [error], reason: 'the previous handler is chained');
    expect(reporter.reports, hasLength(1));
    expect(reporter.reports.single.message, 'Uncaught platform error');
    expect(reporter.reports.single.error, same(error));
    expect(reporter.reports.single.stack, same(stack));
  });

  test('the returned callback restores the previous handlers', () {
    final dispatcher = PlatformDispatcher.instance;
    final flutterBefore = FlutterError.onError;
    final platformBefore = dispatcher.onError;

    installUncaughtErrorHandlers(container.read(loggingServiceProvider))();

    expect(FlutterError.onError, same(flutterBefore));
    expect(dispatcher.onError, same(platformBefore));
  });
}
