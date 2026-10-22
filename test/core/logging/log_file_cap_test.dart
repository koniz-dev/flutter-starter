// FileLogOutput keeps at most maxFiles files, the current one included.
// Rotation used to shift `.1..maxFiles-1` up
// to `.maxFiles`, so the directory held maxFiles + 1.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_starter/core/logging/log_output.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;

const _channel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory documents;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('log_file_cap');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return documents.path;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    documents.deleteSync(recursive: true);
  });

  Directory logs() => Directory(path.join(documents.path, 'logs'));

  Set<String> names() => {
    for (final f in logs().listSync().whereType<File>()) path.basename(f.path),
  };

  /// Writes enough, with pauses for the async rotation, to rotate many times.
  Future<void> rotateMany(FileLogOutput output) async {
    for (var round = 0; round < 8; round++) {
      for (var i = 0; i < 4; i++) {
        final line = 'round $round line $i, long enough to cross the cap';
        output.output(OutputEvent(LogEvent(Level.info, line), [line]));
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  for (final (maxFiles, expected) in [
    (1, {'cap.log'}),
    (2, {'cap.log', 'cap.log.1'}),
    (3, {'cap.log', 'cap.log.1', 'cap.log.2'}),
  ]) {
    test('criterion 1: maxFiles: $maxFiles keeps exactly $expected', () async {
      final output = FileLogOutput(
        fileName: 'cap.log',
        maxFileSize: 64,
        maxFiles: maxFiles,
      );
      addTearDown(output.destroy);
      await output.init();

      await rotateMany(output);

      expect(names(), expected);
      expect(await output.getLogFiles(), hasLength(maxFiles));
    });
  }

  test('a generation left by a build that kept one more is removed', () async {
    // What the old rotation left behind with maxFiles: 3.
    logs().createSync(recursive: true);
    for (final name in ['cap.log.1', 'cap.log.2', 'cap.log.3']) {
      File(path.join(logs().path, name)).writeAsStringSync('old\n');
    }
    final output = FileLogOutput(
      fileName: 'cap.log',
      maxFileSize: 64,
      maxFiles: 3,
    );
    addTearDown(output.destroy);
    await output.init();

    await rotateMany(output);

    expect(names(), {'cap.log', 'cap.log.1', 'cap.log.2'});
  });
}
