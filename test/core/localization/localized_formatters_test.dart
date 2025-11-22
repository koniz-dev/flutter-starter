import 'package:flutter/material.dart';
import 'package:flutter_starter/core/localization/localized_formatters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  group('LocalizedFormatters', () {
    const testLocale = Locale('en', 'US');

    group('formatDate', () {
      test('should format date with default format', () {
        final date = DateTime(2023, 12, 25);
        final formatted = LocalizedFormatters.formatDate(
          date,
          locale: testLocale,
        );

        expect(formatted, isNotEmpty);
        expect(formatted, contains('12'));
        expect(formatted, contains('25'));
        expect(formatted, contains('2023'));
      });

      test('should format date with custom format', () {
        final date = DateTime(2023, 12, 25);
        final formatted = LocalizedFormatters.formatDate(
          date,
          locale: testLocale,
          format: 'yyyy-MM-dd',
        );

        expect(formatted, '2023-12-25');
      });
    });

    group('formatTime', () {
      test('should format time with default format', () {
        final time = DateTime(2023, 12, 25, 14, 30);
        final formatted = LocalizedFormatters.formatTime(
          time,
          locale: testLocale,
        );

        expect(formatted, isNotEmpty);
      });

      test('should format time with custom format', () {
        final time = DateTime(2023, 12, 25, 14, 30);
        final formatted = LocalizedFormatters.formatTime(
          time,
          locale: testLocale,
          format: 'HH:mm:ss',
        );

        expect(formatted, '14:30:00');
      });
    });

    group('formatDateTime', () {
      test('should format date and time with default format', () {
        final dateTime = DateTime(2023, 12, 25, 14, 30);
        final formatted = LocalizedFormatters.formatDateTime(
          dateTime,
          locale: testLocale,
        );

        expect(formatted, isNotEmpty);
      });

      test('should format date and time with custom format', () {
        final dateTime = DateTime(2023, 12, 25, 14, 30);
        final formatted = LocalizedFormatters.formatDateTime(
          dateTime,
          locale: testLocale,
          format: 'yyyy-MM-dd HH:mm:ss',
        );

        expect(formatted, '2023-12-25 14:30:00');
      });
    });

    group('formatNumber', () {
      test('should format number with default decimal digits', () {
        final formatted = LocalizedFormatters.formatNumber(
          1234.567,
          locale: testLocale,
        );

        expect(formatted, isNotEmpty);
      });

      test('should format number with custom decimal digits', () {
        final formatted = LocalizedFormatters.formatNumber(
          1234.567,
          locale: testLocale,
          decimalDigits: 2,
        );

        expect(formatted, isNotEmpty);
        // Number may be formatted with locale-specific separators
        // (e.g., '1,234.57')
        expect(formatted.replaceAll(',', ''), contains('1234'));
      });

      test('should format integer', () {
        final formatted = LocalizedFormatters.formatNumber(
          1234,
          locale: testLocale,
        );

        expect(formatted, isNotEmpty);
        // Number may be formatted with locale-specific separators
        // (e.g., '1,234')
        expect(formatted.replaceAll(',', ''), contains('1234'));
      });
    });

    group('formatCurrency', () {
      test('should format currency with currency code', () {
        final formatted = LocalizedFormatters.formatCurrency(
          1234.56,
          locale: testLocale,
          currencyCode: 'USD',
        );

        expect(formatted, isNotEmpty);
        expect(formatted, contains('1,234'));
      });

      test('should format currency without currency code', () {
        final formatted = LocalizedFormatters.formatCurrency(
          1234.56,
          locale: testLocale,
        );

        expect(formatted, isNotEmpty);
      });

      test('should format currency with custom decimal digits', () {
        final formatted = LocalizedFormatters.formatCurrency(
          1234.567,
          locale: testLocale,
          currencyCode: 'USD',
          decimalDigits: 2,
        );

        expect(formatted, isNotEmpty);
      });
    });

    group('formatPercentage', () {
      test('should format percentage with default decimal digits', () {
        final formatted = LocalizedFormatters.formatPercentage(
          0.15,
          locale: testLocale,
        );

        expect(formatted, isNotEmpty);
        expect(formatted, contains('%'));
      });

      test('should format percentage with custom decimal digits', () {
        final formatted = LocalizedFormatters.formatPercentage(
          0.1567,
          locale: testLocale,
          decimalDigits: 2,
        );

        expect(formatted, isNotEmpty);
        expect(formatted, contains('%'));
      });
    });

    group('formatCompactNumber', () {
      test('should format compact number for thousands', () {
        final formatted = LocalizedFormatters.formatCompactNumber(
          1234,
          locale: testLocale,
        );

        expect(formatted, isNotEmpty);
      });

      test('should format compact number for millions', () {
        final formatted = LocalizedFormatters.formatCompactNumber(
          1234567,
          locale: testLocale,
        );

        expect(formatted, isNotEmpty);
      });
    });

    group('formatRelativeTime', () {
      test('should format "just now" for recent time', () {
        final now = DateTime.now();
        final formatted = LocalizedFormatters.formatRelativeTime(
          now,
          locale: testLocale,
        );

        expect(formatted, isNotEmpty);
      });

      test('should format minutes ago', () {
        final time = DateTime.now().subtract(const Duration(minutes: 5));
        final formatted = LocalizedFormatters.formatRelativeTime(
          time,
          locale: testLocale,
        );

        expect(formatted, isNotEmpty);
        expect(formatted.toLowerCase(), contains('minute'));
      });

      test('should format hours ago', () {
        final time = DateTime.now().subtract(const Duration(hours: 2));
        final formatted = LocalizedFormatters.formatRelativeTime(
          time,
          locale: testLocale,
        );

        expect(formatted, isNotEmpty);
        expect(formatted.toLowerCase(), contains('hour'));
      });

      test('should format days ago', () {
        final time = DateTime.now().subtract(const Duration(days: 3));
        final formatted = LocalizedFormatters.formatRelativeTime(
          time,
          locale: testLocale,
        );

        expect(formatted, isNotEmpty);
        expect(formatted.toLowerCase(), contains('day'));
      });

      test('should format months ago', () {
        final time = DateTime.now().subtract(const Duration(days: 60));
        final formatted = LocalizedFormatters.formatRelativeTime(
          time,
          locale: testLocale,
        );

        expect(formatted, isNotEmpty);
        expect(formatted.toLowerCase(), contains('month'));
      });

      test('should format years ago', () {
        final time = DateTime.now().subtract(const Duration(days: 400));
        final formatted = LocalizedFormatters.formatRelativeTime(
          time,
          locale: testLocale,
        );

        expect(formatted, isNotEmpty);
        expect(formatted.toLowerCase(), contains('year'));
      });
    });

    group('different locales', () {
      test('should format with Vietnamese locale', () async {
        await initializeDateFormatting('vi');
        const viLocale = Locale('vi', 'VN');
        final date = DateTime(2023, 12, 25);
        final formatted = LocalizedFormatters.formatDate(
          date,
          locale: viLocale,
        );

        expect(formatted, isNotEmpty);
      });

      test('should format with Arabic locale', () async {
        await initializeDateFormatting('ar');
        const arLocale = Locale('ar', 'SA');
        final date = DateTime(2023, 12, 25);
        final formatted = LocalizedFormatters.formatDate(
          date,
          locale: arLocale,
        );

        expect(formatted, isNotEmpty);
      });
    });
  });
}
