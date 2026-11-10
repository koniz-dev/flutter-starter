import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_starter/core/logging/i_error_reporter.dart';
import 'package:flutter_starter/core/logging/log_output.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import '1192-baseline-handlers.dart';
import 'package:flutter_test/flutter_test.dart';

class _Reporter implements IErrorReporter {
  final errors = <Object?>[];

  @override
  Future<void> recordError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) async {
    errors.add(error);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'URL credentials stay absent from reporter, file and chained handlers',
    () async {
      final directory = Directory.systemTemp.createTempSync('url_credentials_');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            ..setMockMethodCallHandler(channel, (_) async => directory.path);
      final output = FileLogOutput();
      var closed = false;
      addTearDown(() async {
        if (!closed) await output.destroy();
        messenger.setMockMethodCallHandler(channel, null);
        directory.deleteSync(recursive: true);
      });
      await output.init();
      final reporter = _Reporter();
      final logger = LoggingService(
        enableLogging: true,
        errorReporter: reporter,
        output: output,
      );
      final dispatcher = PlatformDispatcher.instance;
      final savedFlutter = FlutterError.onError;
      final savedPlatform = dispatcher.onError;
      final flutterCalls = <FlutterErrorDetails>[];
      final platformCalls = <Object>[];
      FlutterError.onError = flutterCalls.add;
      dispatcher.onError = (error, stack) {
        platformCalls.add(error);
        return false;
      };
      final restore = installUncaughtErrorHandlers(logger);
      addTearDown(() {
        restore();
        FlutterError.onError = savedFlutter;
        dispatcher.onError = savedPlatform;
      });

      const urls = [
        'https://app.example.com/cb#access_token=FRAGMENT_SECRET&x=1',
        'https://app.example.com/cb#id_token=ID_SECRET&x=1',
        '/verify?token=RELATIVE_SECRET&x=1',
        'ws://h.example.com/socket?ticket=TICKET_SECRET&x=1',
      ];
      for (final url in urls) {
        final error = StateError('request ($url) failed');
        final stack = StackTrace.current;
        expect(dispatcher.onError!(error, stack), isTrue);
        FlutterError.reportError(
          FlutterErrorDetails(exception: error, stack: stack),
        );
      }
      await output.destroy();
      closed = true;

      expect(reporter.errors, hasLength(8));
      expect(platformCalls, hasLength(4));
      expect(flutterCalls, hasLength(4));
      final fileText = latin1.decode(
        File('${directory.path}/logs/app.log').readAsBytesSync(),
      );
      for (final text in [
        fileText,
        ...reporter.errors.map((error) => error.toString()),
        ...platformCalls.map((error) => error.toString()),
        ...flutterCalls.map((details) => details.toString()),
      ]) {
        for (final secret in [
          'FRAGMENT_SECRET',
          'ID_SECRET',
          'RELATIVE_SECRET',
          'TICKET_SECRET',
        ]) {
          expect(text, isNot(contains(secret)));
        }
        expect(
          text.replaceAll(RegExp(r'\s+'), ' '),
          contains('&x=1) failed'),
        );
        expect(text, contains('***REDACTED***'));
      }
    },
  );
}
