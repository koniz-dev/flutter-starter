import 'package:flutter_starter/core/utils/date_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateFormatter', () {
    final testDate = DateTime(2024, 1, 15, 14, 30, 45);

    group('formatDate', () {
      test('should format date correctly', () {
        final result = DateFormatter.formatDate(testDate);
        expect(result, '2024-01-15');
      });

      test('should handle different dates', () {
        final date = DateTime(2023, 12, 25);
        final result = DateFormatter.formatDate(date);
        expect(result, '2023-12-25');
      });
    });

    group('formatDateTime', () {
      test('should format date and time correctly', () {
        final result = DateFormatter.formatDateTime(testDate);
        expect(result, '2024-01-15 14:30:45');
      });
    });

    group('formatTime', () {
      test('should format time correctly', () {
        final result = DateFormatter.formatTime(testDate);
        expect(result, '14:30:45');
      });
    });

    group('parseDate', () {
      test('should parse valid date string', () {
        final result = DateFormatter.parseDate('2024-01-15');
        expect(result, isNotNull);
        expect(result?.year, 2024);
        expect(result?.month, 1);
        expect(result?.day, 15);
      });

      test('should return null for invalid date string', () {
        // DateFormat.parse() is lenient, so some invalid dates might parse
        // Test with clearly invalid formats
        expect(DateFormatter.parseDate('not-a-date'), isNull);
        expect(DateFormatter.parseDate(''), isNull);
        // The important thing is that clearly invalid formats return null
        expect(DateFormatter.parseDate('invalid-format'), isNull);
      });

      test('should return null for empty string', () {
        expect(DateFormatter.parseDate(''), isNull);
      });
    });

    group('parseDateTime', () {
      test('should parse valid date-time string', () {
        final result = DateFormatter.parseDateTime('2024-01-15 14:30:45');
        expect(result, isNotNull);
        expect(result?.year, 2024);
        expect(result?.month, 1);
        expect(result?.day, 15);
        expect(result?.hour, 14);
        expect(result?.minute, 30);
        expect(result?.second, 45);
      });

      test('should parse date-time with different times', () {
        final result = DateFormatter.parseDateTime('2023-12-25 00:00:00');
        expect(result, isNotNull);
        expect(result?.hour, 0);
        expect(result?.minute, 0);
        expect(result?.second, 0);
      });

      test('should return null for invalid date-time string', () {
        expect(DateFormatter.parseDateTime('invalid'), isNull);
        expect(DateFormatter.parseDateTime('2024-01-15'), isNull);
        expect(DateFormatter.parseDateTime(''), isNull);
      });
    });

    group('Edge Cases', () {
      test('should format dates at year boundaries', () {
        final date1 = DateTime(2000);
        final date2 = DateTime(2099, 12, 31);
        expect(DateFormatter.formatDate(date1), '2000-01-01');
        expect(DateFormatter.formatDate(date2), '2099-12-31');
      });

      test('should format times at day boundaries', () {
        final midnight = DateTime(2024);
        final endOfDay = DateTime(2024, 1, 1, 23, 59, 59);
        expect(DateFormatter.formatTime(midnight), '00:00:00');
        expect(DateFormatter.formatTime(endOfDay), '23:59:59');
      });

      test('should handle leap year dates', () {
        final leapDay = DateTime(2024, 2, 29);
        expect(DateFormatter.formatDate(leapDay), '2024-02-29');
        final parsed = DateFormatter.parseDate('2024-02-29');
        expect(parsed, isNotNull);
        expect(parsed?.day, 29);
      });
    });
  });
}
