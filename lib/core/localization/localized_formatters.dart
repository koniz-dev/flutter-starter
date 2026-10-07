import 'package:flutter/material.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// Localized formatting utilities
///
/// Provides date, time, number, and currency formatting based on locale
class LocalizedFormatters {
  LocalizedFormatters._();

  /// Format date to localized string
  ///
  /// [date] - The date to format
  /// [locale] - The locale to use for formatting
  /// [format] - Optional custom format pattern (e.g., 'yyyy-MM-dd')
  static String formatDate(
    DateTime date, {
    required Locale locale,
    String? format,
  }) {
    if (format != null) {
      return DateFormat(format, locale.toString()).format(date);
    }
    return DateFormat.yMd(locale.toString()).format(date);
  }

  /// Format time to localized string
  ///
  /// [time] - The DateTime to extract time from
  /// [locale] - The locale to use for formatting
  /// [format] - Optional custom format pattern (e.g., 'HH:mm:ss')
  static String formatTime(
    DateTime time, {
    required Locale locale,
    String? format,
  }) {
    if (format != null) {
      return DateFormat(format, locale.toString()).format(time);
    }
    return DateFormat.jm(locale.toString()).format(time);
  }

  /// Format date and time to localized string
  ///
  /// [dateTime] - The DateTime to format
  /// [locale] - The locale to use for formatting
  /// [format] - Optional custom format pattern
  static String formatDateTime(
    DateTime dateTime, {
    required Locale locale,
    String? format,
  }) {
    if (format != null) {
      return DateFormat(format, locale.toString()).format(dateTime);
    }
    return DateFormat.yMd(locale.toString()).add_jm().format(dateTime);
  }

  /// Format number to localized string
  ///
  /// [number] - The number to format
  /// [locale] - The locale to use for formatting
  /// [decimalDigits] - Number of decimal digits (default: 2)
  static String formatNumber(
    num number, {
    required Locale locale,
    int? decimalDigits,
  }) {
    final formatter = NumberFormat.decimalPattern(locale.toString());
    if (decimalDigits != null) {
      formatter
        ..minimumFractionDigits = decimalDigits
        ..maximumFractionDigits = decimalDigits;
    }
    return formatter.format(number);
  }

  /// Format currency to localized string
  ///
  /// [amount] - The amount to format
  /// [locale] - The locale to use for formatting
  /// [currencyCode] - ISO 4217 currency code (e.g., 'USD', 'EUR')
  /// [decimalDigits] - Number of decimal digits (default: 2)
  static String formatCurrency(
    num amount, {
    required Locale locale,
    String? currencyCode,
    int? decimalDigits,
  }) {
    if (currencyCode == null) {
      return NumberFormat.simpleCurrency(
        locale: locale.toString(),
        decimalDigits: decimalDigits,
      ).format(amount);
    }

    // `name` is what makes intl apply the currency's own minor-unit count -
    // without it every currency inherited the locale's default of 2, so JPY,
    // KRW and VND (all zero-decimal) were formatted with cents.
    return NumberFormat.currency(
      locale: locale.toString(),
      name: currencyCode,
      symbol: _getCurrencySymbol(currencyCode, locale),
      decimalDigits: decimalDigits,
    ).format(amount);
  }

  /// Get currency symbol for currency code
  static String _getCurrencySymbol(String currencyCode, Locale locale) {
    // Common currency symbols
    const symbols = {
      'USD': r'$',
      'EUR': '€',
      'GBP': '£',
      'JPY': '¥',
      'CNY': '¥',
      'INR': '₹',
      'AUD': r'A$',
      'CAD': r'C$',
      'CHF': 'CHF',
      'SGD': r'S$',
      'HKD': r'HK$',
      'SAR': 'ر.س',
      'AED': 'د.إ',
      'EGP': 'E£',
    };

    return symbols[currencyCode] ?? currencyCode;
  }

  /// Format percentage to localized string
  ///
  /// [value] - The percentage value (0.15 for 15%)
  /// [locale] - The locale to use for formatting
  /// [decimalDigits] - Number of decimal digits (default: 1)
  static String formatPercentage(
    num value, {
    required Locale locale,
    int? decimalDigits,
  }) {
    final formatter = NumberFormat.percentPattern(locale.toString());
    if (decimalDigits != null) {
      formatter
        ..minimumFractionDigits = decimalDigits
        ..maximumFractionDigits = decimalDigits;
    }
    return formatter.format(value);
  }

  /// Format compact number (e.g., 1.2K, 1.5M)
  ///
  /// [number] - The number to format
  /// [locale] - The locale to use for formatting
  static String formatCompactNumber(num number, {required Locale locale}) {
    return NumberFormat.compact(locale: locale.toString()).format(number);
  }

  /// Format relative time, in the past or the future.
  ///
  /// With `en` and a reference time `now`:
  /// - `now.subtract(Duration(hours: 2))` -> `"2 hours ago"`
  /// - `now.add(Duration(hours: 2))` -> `"in 2 hours"`
  /// - `now.add(Duration(days: 3))` -> `"in 3 days"`
  /// - anything less than a minute either side of `now` -> `"Just now"`
  ///
  /// Each unit is truncated, not rounded, in both directions: 1 day and 23
  /// hours ahead reads `"in 1 day"`, exactly as 1 day and 23 hours back reads
  /// `"1 day ago"`. Months are 30 days and years are 365 days.
  ///
  /// [dateTime] - The DateTime to format
  /// [locale] - The locale to use for formatting
  /// [now] - The reference time; defaults to `DateTime.now()`. Pass it when
  ///   the result must be deterministic, e.g. in tests, since a target built
  ///   from `DateTime.now()` is already slightly in the past by the time this
  ///   reads the clock again.
  ///
  /// The strings come from the ARB files in `lib/l10n/` (`*Ago` for the past,
  /// `*FromNow` for the future), so the result is genuinely translated.
  static String formatRelativeTime(
    DateTime dateTime, {
    required Locale locale,
    DateTime? now,
  }) {
    final l10n = _lookup(locale);
    final reference = now ?? DateTime.now();
    final ahead = dateTime.difference(reference);

    if (ahead.inMinutes > 0) {
      if (ahead.inDays > 365) {
        return l10n.yearsFromNow((ahead.inDays / 365).floor());
      } else if (ahead.inDays > 30) {
        return l10n.monthsFromNow((ahead.inDays / 30).floor());
      } else if (ahead.inDays > 0) {
        return l10n.daysFromNow(ahead.inDays);
      } else if (ahead.inHours > 0) {
        return l10n.hoursFromNow(ahead.inHours);
      }
      return l10n.minutesFromNow(ahead.inMinutes);
    }

    final difference = reference.difference(dateTime);
    if (difference.inDays > 365) {
      return l10n.yearsAgo((difference.inDays / 365).floor());
    } else if (difference.inDays > 30) {
      return l10n.monthsAgo((difference.inDays / 30).floor());
    } else if (difference.inDays > 0) {
      return l10n.daysAgo(difference.inDays);
    } else if (difference.inHours > 0) {
      return l10n.hoursAgo(difference.inHours);
    } else {
      // `minutesAgo` renders 0 as "just now" in every locale, which is also
      // where anything under a minute ahead of [reference] lands.
      return l10n.minutesAgo(difference.inMinutes.clamp(0, 59));
    }
  }

  /// Resolve the ARB strings for [locale], falling back to the default locale
  /// when [locale] is not one the app ships.
  static AppLocalizations _lookup(Locale locale) {
    final supported =
        SupportedLocale.fromLanguageCode(locale.languageCode) ??
        SupportedLocale.fallback;
    return lookupAppLocalizations(supported.locale);
  }
}
