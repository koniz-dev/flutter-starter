import 'package:flutter_starter/shared/extensions/datetime_extensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateTimeExtensions', () {
    group('isToday', () {
      test('should return true for today', () {
        final today = DateTime.now();
        expect(today.isToday, isTrue);
      });

      test('should return false for yesterday', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        expect(yesterday.isToday, isFalse);
      });

      test('should return false for tomorrow', () {
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        expect(tomorrow.isToday, isFalse);
      });
    });

    group('isYesterday', () {
      test('should return true for yesterday', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        expect(yesterday.isYesterday, isTrue);
      });

      test('should return false for today', () {
        final today = DateTime.now();
        expect(today.isYesterday, isFalse);
      });

      test('should return false for two days ago', () {
        final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
        expect(twoDaysAgo.isYesterday, isFalse);
      });
    });

    group('isTomorrow', () {
      test('should return true for tomorrow', () {
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        expect(tomorrow.isTomorrow, isTrue);
      });

      test('should return false for today', () {
        final today = DateTime.now();
        expect(today.isTomorrow, isFalse);
      });

      test('should return false for two days from now', () {
        final twoDaysFromNow = DateTime.now().add(const Duration(days: 2));
        expect(twoDaysFromNow.isTomorrow, isFalse);
      });
    });

    group('startOfDay', () {
      test('should return start of day', () {
        final date = DateTime(2024, 1, 15, 14, 30, 45);
        final start = date.startOfDay;
        expect(start.year, 2024);
        expect(start.month, 1);
        expect(start.day, 15);
        expect(start.hour, 0);
        expect(start.minute, 0);
        expect(start.second, 0);
      });
    });

    group('endOfDay', () {
      test('should return end of day', () {
        final date = DateTime(2024, 1, 15, 14, 30, 45);
        final end = date.endOfDay;
        expect(end.year, 2024);
        expect(end.month, 1);
        expect(end.day, 15);
        expect(end.hour, 23);
        expect(end.minute, 59);
        expect(end.second, 59);
      });
    });

    group('toDateString', () {
      test('should format date as yyyy-MM-dd', () {
        final date = DateTime(2024, 1, 15);
        expect(date.toDateString(), '2024-01-15');
      });

      test('should pad single digit month and day', () {
        final date = DateTime(2024, 3, 5);
        expect(date.toDateString(), '2024-03-05');
      });
    });

    group('toTimeString', () {
      test('should format time as HH:mm:ss', () {
        final date = DateTime(2024, 1, 15, 14, 30, 45);
        expect(date.toTimeString(), '14:30:45');
      });

      test('should pad single digit hours, minutes, seconds', () {
        final date = DateTime(2024, 1, 15, 5, 3, 7);
        expect(date.toTimeString(), '05:03:07');
      });
    });

    group('toDateTimeString', () {
      test('should format date and time', () {
        final date = DateTime(2024, 1, 15, 14, 30, 45);
        expect(date.toDateTimeString(), '2024-01-15 14:30:45');
      });

      test('should combine toDateString and toTimeString', () {
        final date = DateTime(2024, 12, 31, 23, 59, 59);
        final expected = '${date.toDateString()} ${date.toTimeString()}';
        expect(date.toDateTimeString(), expected);
      });
    });

    group('Edge Cases', () {
      test('startOfDay should handle leap year', () {
        final leapDay = DateTime(2024, 2, 29, 12, 30, 45);
        final start = leapDay.startOfDay;
        expect(start.day, 29);
        expect(start.month, 2);
        expect(start.hour, 0);
      });

      test('endOfDay should handle year boundaries', () {
        final newYearEve = DateTime(2023, 12, 31, 12);
        final end = newYearEve.endOfDay;
        expect(end.year, 2023);
        expect(end.month, 12);
        expect(end.day, 31);
        expect(end.hour, 23);
        expect(end.minute, 59);
        expect(end.second, 59);
        expect(end.millisecond, 999);
      });

      test('toDateString should handle year boundaries', () {
        final newYear = DateTime(2000);
        expect(newYear.toDateString(), '2000-01-01');
      });

      test('toTimeString should handle midnight', () {
        final midnight = DateTime(2024);
        expect(midnight.toTimeString(), '00:00:00');
      });
    });
  });
}
