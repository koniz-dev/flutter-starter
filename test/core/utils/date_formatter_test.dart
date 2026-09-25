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
        expect(DateFormatter.parseDate('not-a-date'), isNull);
        expect(DateFormatter.parseDate(''), isNull);
        expect(DateFormatter.parseDate('invalid-format'), isNull);
      });

      test('rejects out-of-range calendar fields instead of rolling over', () {
        // DateFormat.parse is lenient: it returned 1 March 2024 and
        // 1 January 2025 for these. parseStrict returns null.
        expect(DateFormatter.parseDate('2024-02-30'), isNull);
        expect(DateFormatter.parseDate('2024-13-01'), isNull);
        expect(DateFormatter.parseDate('2023-02-29'), isNull);
        expect(DateFormatter.parseDate('2024-04-31'), isNull);
        expect(DateFormatter.parseDate('2024-00-10'), isNull);
        expect(DateFormatter.parseDate('2024-01-32'), isNull);
      });

      test('rejects trailing junk after a well-formed date', () {
        expect(DateFormatter.parseDate('2024-01-15 and more'), isNull);
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

      test('rejects out-of-range calendar and clock fields', () {
        expect(DateFormatter.parseDateTime('2024-02-30 00:00:00'), isNull);
        expect(DateFormatter.parseDateTime('2024-13-01 00:00:00'), isNull);
        expect(DateFormatter.parseDateTime('2024-01-15 25:00:00'), isNull);
        expect(DateFormatter.parseDateTime('2024-01-15 14:61:00'), isNull);
      });
    });

    group('timezone round trip', () {
      test('formatIso8601 always emits a UTC instant ending in Z', () {
        final utc = DateTime.utc(2024, 1, 15, 14, 30, 45);
        expect(DateFormatter.formatIso8601(utc), '2024-01-15T14:30:45.000Z');
        expect(DateFormatter.formatIso8601(utc).endsWith('Z'), isTrue);

        // A local DateTime is converted, not relabelled.
        final local = DateTime(2024, 1, 15, 14, 30, 45);
        expect(DateFormatter.formatIso8601(local).endsWith('Z'), isTrue);
        expect(
          DateFormatter.formatIso8601(local),
          local.toUtc().toIso8601String(),
        );
      });

      test('a UTC DateTime survives the ISO-8601 round trip unshifted', () {
        final utc = DateTime.utc(2024, 1, 15, 14, 30, 45);
        final roundTripped = DateFormatter.parseIso8601(
          DateFormatter.formatIso8601(utc),
        );

        expect(roundTripped, isNotNull);
        expect(roundTripped!.isUtc, isTrue);
        expect(roundTripped, utc);
        expect(
          roundTripped.difference(utc),
          Duration.zero,
          reason: 'no timezone shift on a format/parse round trip',
        );
      });

      test('a local DateTime survives the ISO-8601 round trip as an '
          'instant', () {
        final local = DateTime(2024, 6, 30, 23, 59, 59);
        final roundTripped = DateFormatter.parseIso8601(
          DateFormatter.formatIso8601(local),
        );

        expect(roundTripped, isNotNull);
        expect(roundTripped!.isUtc, isTrue);
        expect(roundTripped.isAtSameMomentAs(local), isTrue);
        expect(roundTripped.toLocal(), local);
      });

      test('parseIso8601 normalises an explicit offset to UTC', () {
        final parsed = DateFormatter.parseIso8601('2024-01-15T14:30:45+07:00');
        expect(parsed, DateTime.utc(2024, 1, 15, 7, 30, 45));
        expect(parsed!.isUtc, isTrue);
      });

      test('parseIso8601 rejects rubbish and out-of-range dates', () {
        expect(DateFormatter.parseIso8601('not a date'), isNull);
        expect(DateFormatter.parseIso8601(''), isNull);
        // DateTime.parse is lenient here too: it returns 1 March 2024.
        expect(DateFormatter.parseIso8601('2024-02-30T00:00:00Z'), isNull);
        expect(DateFormatter.parseIso8601('2024-13-01T00:00:00Z'), isNull);
      });

      test('the wall-clock pair is documented as local, and stays local', () {
        // formatDateTime writes no timezone marker, so parseDateTime reads
        // the digits back as local time. That contract is unchanged by this
        // fix - anything already persisted through it reads back exactly as
        // it did before.
        final local = DateTime(2024, 1, 15, 14, 30, 45);
        final text = DateFormatter.formatDateTime(local);
        expect(text, '2024-01-15 14:30:45');
        final parsed = DateFormatter.parseDateTime(text);
        expect(parsed, local);
        expect(parsed!.isUtc, isFalse);
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
