// `package:logger` calls `output.init()` from the `Logger` constructor, after
// LoggingService had already started FileLogOutput.init(). The second init
// opened another sink on the same file and replaced the first without
// closing it: lines still buffered in the first were lost and its file
// descriptor leaked. That made uncaught_error_handlers_test.dart fail under
// load with only the first line of an error in the file.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_starter/core/logging/log_output.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

const _channel = MethodChannel('plugins.flutter.io/path_provider');

OutputEvent _event(List<String> lines) =>
    OutputEvent(LogEvent(Level.error, 'x'), lines);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('log_init_once_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (_) async => dir.path);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    dir.deleteSync(recursive: true);
  });

  String logText() => File('${dir.path}/logs/app.log').readAsStringSync();

  /// Completes when [sink] is closed; times out to false if it never is.
  Future<bool> closed(IOSink sink) => sink.done
      .then((_) => true, onError: (Object _) => true)
      .timeout(const Duration(seconds: 2), onTimeout: () => false);

  test('a second init with a sink open keeps it and loses no line', () async {
    final output = FileLogOutput();
    await output.init();
    final first = output.debugSink!;

    final second = output.init();
    output.output(_event(['A1', 'A2', 'A3']));
    await second;
    output.output(_event(['B1', 'B2']));

    expect(output.debugSink, same(first));
    await output.destroy();
    expect(logText(), 'A1\nA2\nA3\nB1\nB2\n');
    expect(await closed(first), isTrue);
  });

  test('concurrent inits open one sink', () async {
    final output = FileLogOutput();
    final a = output.init();
    final b = output.init();
    await Future.wait([a, b]);
    final sink = output.debugSink!;

    output.output(_event(['C1', 'C2']));
    await output.destroy();

    expect(logText(), 'C1\nC2\n');
    expect(await closed(sink), isTrue);
  });

  test("Logger's own init call does not replace the sink", () async {
    final output = FileLogOutput();
    await output.init();
    final first = output.debugSink!;

    final logger = Logger(output: output, printer: SimplePrinter());
    await logger.init;

    expect(output.debugSink, same(first));
    await output.destroy();
    expect(await closed(first), isTrue);
  });

  test('init after destroy opens the file again', () async {
    final output = FileLogOutput();
    await output.init();
    output.output(_event(['D1']));
    await output.destroy();

    await output.init();
    expect(output.isWritable, isTrue);
    output.output(_event(['D2']));
    await output.destroy();

    expect(logText(), 'D1\nD2\n');
  });
}
