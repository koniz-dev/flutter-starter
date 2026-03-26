import 'package:flutter_starter/core/logging/log_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LogLevel enum', () {
    test('has four values', () {
      expect(LogLevel.values.length, equals(4));
    });

    test('contains expected values', () {
      expect(
        LogLevel.values,
        containsAll([
          LogLevel.debug,
          LogLevel.info,
          LogLevel.warning,
          LogLevel.error,
        ]),
      );
    });
  });

  group('LogLevelExtension.name', () {
    test('debug returns DEBUG', () {
      expect(LogLevel.debug.name, equals('DEBUG'));
    });

    test('info returns INFO', () {
      expect(LogLevel.info.name, equals('INFO'));
    });

    test('warning returns WARNING', () {
      expect(LogLevel.warning.name, equals('WARNING'));
    });

    test('error returns ERROR', () {
      expect(LogLevel.error.name, equals('ERROR'));
    });

    test('all levels have non-empty names', () {
      for (final level in LogLevel.values) {
        expect(level.name, isNotEmpty);
      }
    });
  });

  group('LogLevelExtension.value', () {
    test('debug returns 0', () {
      expect(LogLevel.debug.value, equals(0));
    });

    test('info returns 1', () {
      expect(LogLevel.info.value, equals(1));
    });

    test('warning returns 2', () {
      expect(LogLevel.warning.value, equals(2));
    });

    test('error returns 3', () {
      expect(LogLevel.error.value, equals(3));
    });

    test('levels are ordered by severity', () {
      expect(LogLevel.debug.value, lessThan(LogLevel.info.value));
      expect(LogLevel.info.value, lessThan(LogLevel.warning.value));
      expect(LogLevel.warning.value, lessThan(LogLevel.error.value));
    });

    test('all levels have unique values', () {
      final values = LogLevel.values.map((l) => l.value).toList();
      expect(values.toSet().length, equals(values.length));
    });
  });

  group('LogLevel comparison', () {
    test('can sort levels by value', () {
      final shuffled = [
        LogLevel.error,
        LogLevel.debug,
        LogLevel.warning,
        LogLevel.info,
      ]..sort((a, b) => a.value.compareTo(b.value));

      expect(
        shuffled,
        equals([
          LogLevel.debug,
          LogLevel.info,
          LogLevel.warning,
          LogLevel.error,
        ]),
      );
    });

    test('can filter levels above threshold', () {
      const threshold = LogLevel.warning;
      final filtered = LogLevel.values
          .where((l) => l.value >= threshold.value)
          .toList();

      expect(filtered, containsAll([LogLevel.warning, LogLevel.error]));
      expect(filtered, isNot(contains(LogLevel.debug)));
      expect(filtered, isNot(contains(LogLevel.info)));
    });
  });
}
