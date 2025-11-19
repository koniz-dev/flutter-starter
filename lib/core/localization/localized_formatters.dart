import 'package:flutter/material.dart';
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
    final formatter = currencyCode != null
        ? NumberFormat.currency(
            locale: locale.toString(),
            symbol: '',
            decimalDigits: decimalDigits,
          )
        : NumberFormat.simpleCurrency(
            locale: locale.toString(),
            decimalDigits: decimalDigits,
          );

    if (currencyCode != null) {
      // Get currency symbol from locale
      final currencySymbol = _getCurrencySymbol(currencyCode, locale);
      return '$currencySymbol${formatter.format(amount)}';
    }

    return formatter.format(amount);
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
  static String formatCompactNumber(
    num number, {
    required Locale locale,
  }) {
    return NumberFormat.compact(locale: locale.toString()).format(number);
  }

  /// Format relative time (e.g., "2 hours ago", "in 3 days")
  ///
  /// [dateTime] - The DateTime to format
  /// [locale] - The locale to use for formatting
  static String formatRelativeTime(
    DateTime dateTime, {
    required Locale locale,
  }) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return Intl.message(
        '$years year${years == 1 ? '' : 's'} ago',
        locale: locale.toString(),
      );
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return Intl.message(
        '$months month${months == 1 ? '' : 's'} ago',
        locale: locale.toString(),
      );
    } else if (difference.inDays > 0) {
      return Intl.message(
        '${difference.inDays} day'
        '${difference.inDays == 1 ? '' : 's'} ago',
        locale: locale.toString(),
      );
    } else if (difference.inHours > 0) {
      return Intl.message(
        '${difference.inHours} hour'
        '${difference.inHours == 1 ? '' : 's'} ago',
        locale: locale.toString(),
      );
    } else if (difference.inMinutes > 0) {
      return Intl.message(
        '${difference.inMinutes} minute'
        '${difference.inMinutes == 1 ? '' : 's'} ago',
        locale: locale.toString(),
      );
    } else {
      return Intl.message('Just now', locale: locale.toString());
    }
  }
}
