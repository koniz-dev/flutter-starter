import 'package:flutter_starter/core/logging/crashlytics_output_template.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

void main() {
  group('CrashlyticsOutput Template Tests', () {
    late CrashlyticsOutput output;

    setUp(() {
      output = CrashlyticsOutput();
    });

    test('should construct successfully', () {
      expect(output, isNotNull);
    });

    test('output method does not throw when sending warning logs', () {
      final logEvent = LogEvent(Level.warning, 'Warning trace array');
      final event = OutputEvent(logEvent, ['Warning trace array']);

      // Testing template safely ignoring logic when commented out
      expect(() => output.output(event), returnsNormally);
    });

    test('output method does not throw when sending error logs', () {
      final logEvent = LogEvent(Level.error, 'Error trace array');
      final event = OutputEvent(logEvent, ['Error trace array']);

      expect(() => output.output(event), returnsNormally);
    });

    test('output method ignores info and debug logs gracefully', () {
      final logEvent = LogEvent(Level.info, 'Info trace array');
      final event = OutputEvent(logEvent, ['Info trace array']);

      expect(() => output.output(event), returnsNormally);
    });
  });
}
