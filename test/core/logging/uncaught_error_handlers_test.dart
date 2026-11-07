import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/logging/error_reporter_providers.dart';
import 'package:flutter_starter/core/logging/i_error_reporter.dart';
import 'package:flutter_starter/core/logging/log_output.dart';
import 'package:flutter_starter/core/logging/logging_providers.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
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

  test('uncaught image and platform URL secrets are absent from reporter '
      'and file log', () async {
    final directory = Directory.systemTemp.createTempSync('uncaught_log_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          ..setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      directory.deleteSync(recursive: true);
    });
    final output = FileLogOutput();
    await output.init();
    final logger = LoggingService(
      enableLogging: true,
      errorReporter: reporter,
      output: output,
    );
    final savedFlutter = FlutterError.onError;
    FlutterError.onError = (_) {};
    addTearDown(() => FlutterError.onError = savedFlutter);
    final restore = installUncaughtErrorHandlers(logger);
    addTearDown(restore);
    final stack = StackTrace.current;
    const url =
        'https://PRIVATEUSER:PRIVATEPASS@cdn.example.com/a.png'
        "?download=it's&X-Amz-Signature=SECRETSIG&token=SECRETTOK&width=100";
    for (final imageUrl in [
      url,
      url.replaceFirst('PRIVATEUSER:PRIVATEPASS@', ''),
    ]) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: NetworkImageLoadException(
            statusCode: 403,
            uri: Uri.parse(imageUrl),
          ),
          stack: stack,
        ),
      );
    }
    PlatformDispatcher.instance.onError!(StateError('failed $url'), stack);
    await output.destroy();

    expect(reporter.reports, hasLength(3));
    expect(reporter.reports[1].error, isA<NetworkImageLoadException>());
    expect(reporter.reports.first.error, isA<NetworkImageLoadException>());
    final fileText = latin1.decode(
      File('${directory.path}/logs/app.log').readAsBytesSync(),
    );
    expect(fileText, contains('cdn.example.com'));
    for (final text in [
      fileText,
      for (final report in reporter.reports)
        '${report.message} ${report.error}',
    ]) {
      for (final secret in [
        'PRIVATEUSER',
        'PRIVATEPASS',
        'SECRETSIG',
        'SECRETTOK',
      ]) {
        expect(text, isNot(contains(secret)));
      }
      expect(text, contains('width=100'));
    }
    expect(reporter.reports.last.error.toString(), contains('StateError'));
    for (final report in reporter.reports) {
      expect(report.stack, same(stack));
    }
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
