// A log file that cannot be opened must not escape as an uncaught error
// (koniz-dev/flutter-starter#421).
//
// File.openWrite returns its IOSink synchronously and opens the file later,
// so the try around it in FileLogOutput._initializeLogFile never saw a
// failed open: permission denied surfaced as an uncaught async error in the
// zone, which PlatformDispatcher.onError or a crash reporter would see,
// contradicting "silently continue without file logging".
@TestOn('mac-os || linux')
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_starter/core/logging/log_output.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

const _pathProvider = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory documents;
  late Directory logs;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('log_open_failure');
    logs = Directory('${documents.path}/logs')..createSync();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProvider, (call) async {
          return call.method == 'getApplicationDocumentsDirectory'
              ? documents.path
              : null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProvider, null);
    Process.runSync('chmod', ['755', logs.path]);
    documents.deleteSync(recursive: true);
  });

  OutputEvent line(String text) =>
      OutputEvent(LogEvent(Level.error, text), [text]);

  /// Runs [body] in a guarded zone and returns every error that escaped it.
  Future<List<Object>> uncaughtErrorsOf(
    Future<void> Function() body,
  ) async {
    final errors = <Object>[];
    await runZonedGuarded(() async {
      await body();
      // Let the asynchronous open settle and report.
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }, (error, _) => errors.add(error));
    return errors;
  }

  test(
    'an unwritable logs directory produces no uncaught zone error',
    () async {
      Process.runSync('chmod', ['000', logs.path]);
      late FileLogOutput output;

      // Nothing is logged before the open settles: a pending flush would
      // otherwise consume the open error through its own try, hiding the bug.
      final errors = await uncaughtErrorsOf(() async {
        output = FileLogOutput();
        await output.init();
      });
      // Later log lines are dropped or buffered, never thrown.
      errors.addAll(
        await uncaughtErrorsOf(() async {
          output.output(line('after a failed open'));
        }),
      );

      // ignore: avoid_print - the evidence line for the criterion
      print('VF uncaught=$errors isWritable=${output.isWritable}');
      expect(errors, isEmpty);
      // Criterion 2: the failure is observable.
      expect(output.isWritable, isFalse);
    },
  );

  // koniz-dev/flutter-starter#447: openWrite starts its own lazy open, which
  // dart:io only observes once something is written. A directory that
  // vanished after the probe open made that open fail unobserved - an
  // uncaught error the try and _watch both missed.
  test('a directory removed after the probe open produces no uncaught '
      'zone error', () async {
    late FileLogOutput output;
    final errors = await uncaughtErrorsOf(() async {
      output = FileLogOutput()
        ..debugAfterProbeOpen = () async => logs.deleteSync(recursive: true);
      await output.init();
    });
    errors.addAll(
      await uncaughtErrorsOf(() async {
        output.output(line('after the directory vanished'));
      }),
    );

    // ignore: avoid_print - the evidence line for the criterion
    print(
      'VF447 uncaught=$errors isWritable=${output.isWritable} '
      'pending=${output.pendingLineCount}',
    );
    expect(errors, isEmpty);
    expect(output.isWritable, isFalse);
    // The line is held for a later open, not written into a dead sink.
    expect(output.pendingLineCount, 1);
    // Recreated so tearDown's chmod has a directory to act on.
    logs.createSync();
  });

  test('a writable directory still opens and writes', () async {
    final output = FileLogOutput();
    final errors = await uncaughtErrorsOf(() async {
      await output.init();
      output.output(line('written'));
    });
    addTearDown(output.destroy);

    expect(errors, isEmpty);
    expect(output.isWritable, isTrue);
    expect(
      File('${logs.path}/app.log').readAsStringSync(),
      contains('written'),
    );
  });
}
