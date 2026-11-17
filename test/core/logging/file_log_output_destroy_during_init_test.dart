// destroy() while init() was still opening the log file closed nothing - the
// sink did not exist yet - and init then installed the sink it opened, so a
// destroyed output kept an open file. An open that started before destroy()
// (or clearLogs(), or a rotation) now closes what it made.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_starter/core/logging/log_output.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('log_destroy_init_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (_) async => dir.path);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    dir.deleteSync(recursive: true);
  });

  test('destroy() during init() leaves no sink open', () async {
    final output = FileLogOutput();
    final init = output.init();
    await output.destroy();
    await init;

    expect(output.debugSink, isNull);
    expect(output.isWritable, isFalse);
  });

  test('init() after that destroy() still opens the file', () async {
    final output = FileLogOutput();
    final init = output.init();
    await output.destroy();
    await init;

    await output.init();

    expect(output.isWritable, isTrue);
    await output.destroy();
  });
}
