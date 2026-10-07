// Regression tests for koniz-dev/flutter-starter#65, criteria 7 and 9.
import 'package:flutter/material.dart';
import 'package:flutter_starter/core/localization/localized_formatters.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(initializeDateFormatting);

  group('formatRelativeTime is localized', () {
    final now = DateTime.now();

    test('Arabic does not fall back to English', () {
      final ar = lookupAppLocalizations(const Locale('ar'));
      final threeHoursAgo = now.subtract(const Duration(hours: 3));

      final formatted = LocalizedFormatters.formatRelativeTime(
        threeHoursAgo,
        locale: const Locale('ar'),
      );

      expect(formatted, ar.hoursAgo(3));
      expect(formatted, isNot(contains('hours ago')));
      expect(formatted, contains('ساعات'));
    });

    test('Vietnamese does not fall back to English', () {
      final vi = lookupAppLocalizations(const Locale('vi'));
      final twoDaysAgo = now.subtract(const Duration(days: 2));

      final formatted = LocalizedFormatters.formatRelativeTime(
        twoDaysAgo,
        locale: const Locale('vi'),
      );

      expect(formatted, vi.daysAgo(2));
      expect(formatted, isNot(contains('days ago')));
      expect(formatted, contains('ngày trước'));
    });

    test('Spanish months and years are localized', () {
      final es = lookupAppLocalizations(const Locale('es'));

      expect(
        LocalizedFormatters.formatRelativeTime(
          now.subtract(const Duration(days: 70)),
          locale: const Locale('es'),
        ),
        es.monthsAgo(2),
      );
      expect(
        LocalizedFormatters.formatRelativeTime(
          now.subtract(const Duration(days: 800)),
          locale: const Locale('es'),
        ),
        es.yearsAgo(2),
      );
    });

    test('English keeps its wording', () {
      expect(
        LocalizedFormatters.formatRelativeTime(
          now.subtract(const Duration(hours: 3)),
          locale: const Locale('en', 'US'),
        ),
        '3 hours ago',
      );
      expect(
        LocalizedFormatters.formatRelativeTime(
          now.subtract(const Duration(seconds: 5)),
          locale: const Locale('en', 'US'),
        ),
        'Just now',
      );
    });

    // koniz-dev/flutter-starter#263: the future phrasing is translated too.
    test('future dates use the localized *FromNow strings', () {
      final ref = DateTime.now();
      String format(Duration d, String code) =>
          LocalizedFormatters.formatRelativeTime(
            ref.add(d),
            locale: Locale(code),
            now: ref,
          );

      expect(format(const Duration(hours: 2), 'es'), 'En 2 horas');
      expect(format(const Duration(days: 3), 'es'), 'En 3 días');
      expect(format(const Duration(hours: 2), 'vi'), '2 giờ nữa');
      expect(format(const Duration(days: 3), 'vi'), '3 ngày nữa');
      // Arabic: 2 takes the dual form, 3 the "few" form.
      expect(format(const Duration(hours: 2), 'ar'), 'بعد ساعتين');
      expect(format(const Duration(days: 3), 'ar'), 'بعد 3 أيام');

      for (final code in ['es', 'vi', 'ar']) {
        final l10n = lookupAppLocalizations(Locale(code));
        expect(format(const Duration(days: 3), code), l10n.daysFromNow(3));
        expect(format(const Duration(days: 3), code), isNot(contains('in ')));
        expect(
          format(const Duration(days: 3), code),
          isNot(l10n.minutesAgo(0)),
        );
      }
    });

    test('an unsupported locale falls back to the default, not a crash', () {
      expect(
        () => LocalizedFormatters.formatRelativeTime(
          now.subtract(const Duration(hours: 1)),
          locale: const Locale('de', 'DE'),
        ),
        returnsNormally,
      );
    });
  });

  group('formatCurrency honours the currency minor units', () {
    test('JPY has zero decimals', () {
      final formatted = LocalizedFormatters.formatCurrency(
        1234.5,
        locale: const Locale('en', 'US'),
        currencyCode: 'JPY',
      );

      expect(formatted, '¥1,235');
      expect(formatted, isNot(contains('.')));
    });

    test('VND has zero decimals', () {
      final formatted = LocalizedFormatters.formatCurrency(
        1234.5,
        locale: const Locale('vi', 'VN'),
        currencyCode: 'VND',
      );

      expect(formatted, isNot(contains(',50')));
      expect(formatted, isNot(contains('.50')));
    });

    test('USD still has two decimals', () {
      expect(
        LocalizedFormatters.formatCurrency(
          1234.5,
          locale: const Locale('en', 'US'),
          currencyCode: 'USD',
        ),
        r'$1,234.50',
      );
    });

    test('an explicit decimalDigits still wins', () {
      expect(
        LocalizedFormatters.formatCurrency(
          1234.5,
          locale: const Locale('en', 'US'),
          currencyCode: 'JPY',
          decimalDigits: 2,
        ),
        '¥1,234.50',
      );
    });
  });
}
