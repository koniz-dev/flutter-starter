// LoggingService must write in profile and release builds.
//
// It built its Logger with no `filter:`, so the logger package used its
// default, DevelopmentFilter, which decides inside an `assert`: once asserts
// are off - every profile and release build - it drops every event, and the
// file and console outputs set up for production received nothing.
//
// `flutter test` runs with asserts on, so the real DevelopmentFilter would
// pass here. These tests stand in for release mode by making the package
// default drop everything, which is exactly what DevelopmentFilter does there:
// a LoggingService that relies on the default writes nothing.

import 'dart:io';

import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

/// What DevelopmentFilter amounts to with asserts disabled.
class _ReleaseModeDevelopmentFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) => false;
}

class _RecordingOutput extends LogOutput {
  final List<String> lines = [];

  @override
  void output(OutputEvent event) => lines.addAll(event.lines);
}

void main() {
  late LogFilter Function() originalDefault;

  setUp(() {
    originalDefault = Logger.defaultFilter;
    Logger.defaultFilter = _ReleaseModeDevelopmentFilter.new;
  });

  tearDown(() => Logger.defaultFilter = originalDefault);

  test('info and error reach the output when the package default would drop '
      'them', () {
    final output = _RecordingOutput();
    LoggingService(enableLogging: true, debugMode: false, output: output)
      ..info('release info line')
      ..error('release error line');

    expect(output.lines.join('\n'), contains('release info line'));
    expect(output.lines.join('\n'), contains('release error line'));
  });

  test('outside production the level is debug, and debug lines are written '
      'too', () {
    final output = _RecordingOutput();
    LoggingService(
      enableLogging: true,
      debugMode: false,
      output: output,
    ).debug('release debug line');

    expect(output.lines.join('\n'), contains('release debug line'));
  });

  test('every Logger LoggingService builds names its filter', () {
    final source = File(
      'lib/core/logging/logging_service.dart',
    ).readAsStringSync();
    final constructions = RegExp(r'Logger\(\s*([^)]*)').allMatches(source);

    expect(constructions, isNotEmpty);
    for (final c in constructions) {
      final args = c.group(1)!;
      // `_initializeLogger();` matches the pattern with no arguments.
      if (args.trim().isEmpty) continue;
      expect(args, contains('filter:'), reason: 'Logger($args)');
    }
  });
}
