// A production build must log somewhere by default.
//
// File logging is the output meant for production, but it sat behind
// ENABLE_LOGGING, whose default was false in production, so LoggingService
// built a no-op logger and every production error was dropped. A release
// build that was not production (staging) had no file output and no console
// output either, because the console output is added only under kDebugMode.
//
// Run this file twice to see both environments:
//   flutter test <this file>
//   flutter test <this file> --dart-define=ENVIRONMENT=production

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/config/env_config.dart';
import 'package:flutter_starter/core/logging/log_output.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

const _pathProvider = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory documents;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('production_logging');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProvider, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return documents.path;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProvider, null);
    if (documents.existsSync()) documents.deleteSync(recursive: true);
  });

  /// The contents of logs/app.log once it holds [needle], or what it holds
  /// after a few seconds, so a failure shows what was written.
  Future<String> appLogContaining(String needle) async {
    final file = File('${documents.path}/logs/app.log');
    for (var i = 0; i < 100; i++) {
      if (file.existsSync()) {
        final text = file.readAsStringSync();
        if (text.contains(needle)) return text;
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    return file.existsSync() ? file.readAsStringSync() : '<no logs/app.log>';
  }

  /// Waits until the file output has created logs/app.log, so its init()
  /// cannot outlive the test and race tearDown's directory deletion.
  Future<void> fileOutputOpened() async {
    final file = File('${documents.path}/logs/app.log');
    for (var i = 0; i < 100 && !file.existsSync(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    expect(file.existsSync(), isTrue, reason: 'the file output never opened');
  }

  group('criterion 1: the default LoggingService in this environment', () {
    test('ENABLE_LOGGING is unset, so the environment default applies', () {
      expect(EnvConfig.isInitialized, isFalse);
      expect(EnvConfig.has('ENABLE_LOGGING'), isFalse);
      expect(
        AppConfig.enableLogging,
        isTrue,
        reason: 'logging is on by default in ${AppConfig.environment}',
      );
    });

    test('error() reaches logs/app.log in production '
        '(${AppConfig.environment})', () async {
      final service = LoggingService();
      addTearDown(service.dispose);

      service.error('boom-320', error: StateError('migration failed'));

      final hasFile = service.outputs.whereType<FileLogOutput>().isNotEmpty;
      final written = hasFile ? await appLogContaining('boom-320') : null;
      // ignore: avoid_print - the line is the evidence for criterion 1
      print(
        'VP environment=${AppConfig.environment} '
        'enableLogging=${AppConfig.enableLogging} '
        'outputs=${service.outputs.map((o) => o.runtimeType).toList()} '
        'app.log=${written == null ? 'absent' : '${written.length}B'}',
      );
      if (AppConfig.isProduction) {
        expect(hasFile, isTrue);
        expect(written, contains('boom-320'));
        expect(written, contains('migration failed'));
      } else {
        // Outside production the default is console only.
        expect(service.outputs.whereType<FileLogOutput>(), isEmpty);
      }
    });
  });

  group('criterion 2: outputs are never empty outside kDebugMode', () {
    for (final file in [true, false]) {
      for (final remote in [true, false]) {
        test('file=$file remote=$remote', () async {
          final service = LoggingService(
            enableLogging: true,
            enableFileLogging: file,
            enableRemoteLogging: remote,
            debugMode: false,
          );
          addTearDown(service.dispose);

          expect(service.outputs, isNotEmpty);
          if (file) {
            expect(service.outputs.whereType<FileLogOutput>(), hasLength(1));
            // A production release: the file only, as the guide's table says.
            expect(service.outputs.whereType<ConsoleOutput>(), isEmpty);
            // LoggingService starts FileLogOutput.init() unawaited. Ending the
            // test before it has opened logs/app.log let tearDown delete the
            // directory underneath it, and the open then failed after the
            // test had completed.
            await fileOutputOpened();
          } else {
            // A staging release build: no file and no debug console, so
            // the console is the fallback rather than nothing.
            expect(service.outputs.whereType<ConsoleOutput>(), hasLength(1));
          }
        });
      }
    }

    test('logging disabled still means no outputs', () {
      final service = LoggingService(enableLogging: false, debugMode: false);
      addTearDown(service.dispose);

      expect(service.outputs, isEmpty);
    });
  });
}
