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

  /// Format relative time (e.g., "2 hours ago", "in 3 days")
  ///
  /// [dateTime] - The DateTime to format
  /// [locale] - The locale to use for formatting
  ///
  /// The strings come from the ARB files in `lib/l10n/`, so the result is
  /// genuinely translated. The previous implementation passed an interpolated
  /// (non-literal) string to `Intl.message`, which is never extracted, so it
  /// returned its English argument verbatim for every locale.
  static String formatRelativeTime(
    DateTime dateTime, {
    required Locale locale,
  }) {
    final l10n = _lookup(locale);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return l10n.yearsAgo((difference.inDays / 365).floor());
    } else if (difference.inDays > 30) {
      return l10n.monthsAgo((difference.inDays / 30).floor());
    } else if (difference.inDays > 0) {
      return l10n.daysAgo(difference.inDays);
    } else if (difference.inHours > 0) {
      return l10n.hoursAgo(difference.inHours);
    } else {
      // `minutesAgo` renders 0 as "just now" in every locale.
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
