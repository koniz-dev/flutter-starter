import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/logging/error_reporter_providers.dart';
import 'package:flutter_starter/core/logging/i_error_reporter.dart';
import 'package:flutter_starter/core/logging/log_output.dart';
import 'package:flutter_starter/core/logging/logging_providers.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/logging/uncaught_error_handlers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

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

  test(
    'relative request secrets are absent from reporter and file log',
    () async {
      final directory = Directory.systemTemp.createTempSync('relative_error_');
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
      final restore = installUncaughtErrorHandlers(logger);
      addTearDown(restore);
      for (final path in ['/verify', 'verify', '../verify', '']) {
        PlatformDispatcher.instance.onError!(
          StateError('GET $path?token=RELATIVE_SECRET&mode=check failed'),
          StackTrace.current,
        );
      }
      await output.destroy();

      final fileText = latin1.decode(
        File('${directory.path}/logs/app.log').readAsBytesSync(),
      );
      expect(reporter.reports, hasLength(4));
      for (final text in [
        fileText,
        for (final report in reporter.reports) report.error.toString(),
      ]) {
        expect(text, isNot(contains('RELATIVE_SECRET')));
        expect(
          text,
          contains('token=***REDACTED***&mode=check failed'),
        );
      }
    },
  );

  test('redacted URL errors keep surrounding parentheses and diagnostics', () {
    final restore = installUncaughtErrorHandlers(
      container.read(loggingServiceProvider),
    );
    addTearDown(restore);
    for (final path in [
      'https://app.example/cb',
      '/verify',
      'https://app.example/a(b)',
    ]) {
      for (final punctuation in ['', ',', '.']) {
        PlatformDispatcher.instance.onError!(
          StateError(
            'callback (($path?token=PAREN_SECRET))$punctuation failed',
          ),
          StackTrace.current,
        );
        final text = reporter.reports.last.error.toString();
        expect(text, isNot(contains('PAREN_SECRET')));
        expect(
          text,
          contains(
            'callback (($path?token=***REDACTED***))$punctuation failed',
          ),
        );
      }
    }
  });

  test(
    'previous handlers receive safe errors and retain ordinary identity',
    () {
      final flutterCalls = <FlutterErrorDetails>[];
      final platformCalls = <(Object, StackTrace)>[];
      final dispatcher = PlatformDispatcher.instance;
      final savedFlutter = FlutterError.onError;
      final savedPlatform = dispatcher.onError;
      FlutterError.onError = flutterCalls.add;
      dispatcher.onError = (error, stack) {
        platformCalls.add((error, stack));
        return false;
      };
      addTearDown(() {
        FlutterError.onError = savedFlutter;
        dispatcher.onError = savedPlatform;
      });
      final restore = installUncaughtErrorHandlers(
        container.read(loggingServiceProvider),
      );
      addTearDown(restore);
      final stack = StackTrace.current;
      final context = ErrorDescription('loading account');
      final secret = StateError(
        'failed https://app.example/?token=CHAIN_SECRET',
      );
      final details = FlutterErrorDetails(
        exception: secret,
        stack: stack,
        context: context,
        library: 'fixture library',
        silent: true,
      );
      FlutterError.reportError(details);
      expect(dispatcher.onError!(secret, stack), isTrue);
      for (final error in [
        flutterCalls.single.exception,
        platformCalls.single.$1,
      ]) {
        expect(error.toString(), isNot(contains('CHAIN_SECRET')));
        expect(error.toString(), contains('token=***REDACTED***'));
      }
      expect(
        flutterCalls.single.context!.toDescription(),
        context.toDescription(),
      );
      expect(flutterCalls.single.stack, same(stack));
      expect(flutterCalls.single.library, 'fixture library');
      expect(flutterCalls.single.silent, isTrue);
      expect(platformCalls.single.$2, same(stack));

      final ordinary = StateError('ordinary failure');
      final ordinaryDetails = FlutterErrorDetails(
        exception: ordinary,
        stack: stack,
      );
      FlutterError.reportError(ordinaryDetails);
      dispatcher.onError!(ordinary, stack);
      expect(flutterCalls.last, same(ordinaryDetails));
      expect(platformCalls.last.$1, same(ordinary));
    },
  );

  testWidgets(
    'actual image failure has safe diagnostics in the chained console',
    (
      tester,
    ) async {
      final savedFlutter = FlutterError.onError;
      final savedPrint = debugPrint;
      final received = Completer<FlutterErrorDetails>();
      final console = <String>[];
      debugPrint = (message, {wrapWidth}) => console.add(message ?? '');
      FlutterError.onError = (details) {
        if (!received.isCompleted) received.complete(details);
        FlutterError.dumpErrorToConsole(details, forceReport: true);
      };
      addTearDown(() {
        FlutterError.onError = savedFlutter;
        debugPrint = savedPrint;
      });
      final restore = installUncaughtErrorHandlers(
        LoggingService(enableLogging: false),
      );
      addTearDown(restore);

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Image(
            image: NetworkImage('https://cdn.example/a.png?token=IMAGE_SECRET'),
          ),
        ),
      );
      final details = await tester.runAsync(
        () => received.future.timeout(const Duration(seconds: 5)),
      );
      restore();
      FlutterError.onError = savedFlutter;
      debugPrint = savedPrint;
      expect(details!.exception, isA<NetworkImageLoadException>());
      for (final text in [details.toString(), console.join('\n')]) {
        expect(text, isNot(contains('IMAGE_SECRET')));
        expect(text, contains('Image provider:'));
        expect(text, contains('Image key:'));
        expect(text, contains('token=***REDACTED***'));
      }
    },
  );

  test(
    'ordinary exceptions also redact context and lazy diagnostic values',
    () {
      final savedFlutter = FlutterError.onError;
      FlutterErrorDetails? received;
      FlutterError.onError = (details) => received = details;
      addTearDown(() => FlutterError.onError = savedFlutter);
      final restore = installUncaughtErrorHandlers(
        LoggingService(enableLogging: false),
      );
      addTearDown(restore);
      final ordinary = StateError('load failed');
      final stack = StackTrace.current;
      var collections = 0;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: ordinary,
          stack: stack,
          context: ErrorDescription('loading /verify?token=CONTEXT_SECRET'),
          informationCollector: () {
            collections++;
            return [
              DiagnosticsProperty<Uri>(
                'Request',
                Uri.parse('verify?token=INFO_SECRET&mode=check'),
              ),
            ];
          },
        ),
      );
      expect(collections, 0, reason: 'diagnostic collection stays lazy');
      expect(received!.exception, same(ordinary));
      expect(received!.stack, same(stack));
      final rendered = received.toString();
      expect(collections, greaterThan(0));
      expect(rendered, isNot(contains('CONTEXT_SECRET')));
      expect(rendered, isNot(contains('INFO_SECRET')));
      expect(rendered, contains('mode=check'));
    },
  );

  test('diagnostic levels and nested filtering survive redaction', () {
    final savedFlutter = FlutterError.onError;
    FlutterErrorDetails? received;
    FlutterError.onError = (details) => received = details;
    addTearDown(() => FlutterError.onError = savedFlutter);
    final restore = installUncaughtErrorHandlers(
      LoggingService(enableLogging: false),
    );
    addTearDown(restore);
    final group = DiagnosticsBlock(
      name: 'group',
      level: DiagnosticLevel.warning,
      properties: [
        StringProperty(
          'hidden',
          'HIDDEN_PROPERTY',
          level: DiagnosticLevel.hidden,
        ),
        StringProperty('debug', 'DEBUG_PROPERTY', level: DiagnosticLevel.debug),
        StringProperty('info', 'INFO_PROPERTY'),
        StringProperty(
          'warning',
          'WARNING_PROPERTY',
          level: DiagnosticLevel.warning,
        ),
      ],
      children: [
        DiagnosticsBlock(
          name: 'hidden child',
          level: DiagnosticLevel.hidden,
          properties: [
            StringProperty(
              'value',
              'HIDDEN_CHILD',
              level: DiagnosticLevel.hidden,
            ),
          ],
        ),
        DiagnosticsBlock(
          name: 'visible child',
          properties: [StringProperty('url', '/verify?token=NESTED_SECRET')],
        ),
      ],
    );
    final details = FlutterErrorDetails(
      exception: StateError('ordinary'),
      informationCollector: () => [
        StringProperty(
          'top hidden',
          'HIDDEN_TOP',
          level: DiagnosticLevel.hidden,
        ),
        group,
      ],
    );
    FlutterError.reportError(details);
    final rendered = received.toString();
    for (final hidden in ['HIDDEN_TOP', 'HIDDEN_PROPERTY', 'HIDDEN_CHILD']) {
      expect(details.toString(), isNot(contains(hidden)));
      expect(rendered, isNot(contains(hidden)));
    }
    expect(rendered, isNot(contains('DEBUG_PROPERTY')));
    expect(rendered, contains('INFO_PROPERTY'));
    expect(rendered, contains('WARNING_PROPERTY'));
    expect(rendered, isNot(contains('NESTED_SECRET')));
    final nodes = received!.informationCollector!().toList();
    expect(nodes.first.level, DiagnosticLevel.hidden);
    expect(nodes.last.level, group.level);
    expect(nodes.last.getProperties().first.level, DiagnosticLevel.hidden);
    final warnings = nodes.last.toStringDeep(minLevel: DiagnosticLevel.warning);
    expect(warnings, contains('WARNING_PROPERTY'));
    expect(warnings, isNot(contains('DEBUG_PROPERTY')));
    expect(warnings, isNot(contains('INFO_PROPERTY')));
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
