// FileLogOutput wrote to the app's documents directory, which iOS backs up to
// iCloud and which on Windows and Linux is the user's shared ~/Documents. It
// now writes to the app's cache directory.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_starter/core/logging/log_output.dart';
import 'package:flutter_test/flutter_test.dart';

const _pathProvider = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('log files go to the cache directory, not the documents', () async {
    final documents = Directory.systemTemp.createTempSync('log_docs_');
    final cache = Directory.systemTemp.createTempSync('log_cache_');
    addTearDown(() {
      documents.deleteSync(recursive: true);
      cache.deleteSync(recursive: true);
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProvider, (call) async {
          return switch (call.method) {
            'getApplicationDocumentsDirectory' => documents.path,
            'getApplicationCacheDirectory' => cache.path,
            _ => null,
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pathProvider, null),
    );

    final output = FileLogOutput();
    await output.init();
    await output.destroy();

    expect(File('${cache.path}/logs/app.log').existsSync(), isTrue);
    expect(Directory('${documents.path}/logs').existsSync(), isFalse);
  });
}
