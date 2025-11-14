import 'package:intl/intl.dart';

/// Date formatting utilities
class DateFormatter {
  DateFormatter._();

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final DateFormat _timeFormat = DateFormat('HH:mm:ss');

  /// Format date to string
  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }

  /// Format date and time to string
  static String formatDateTime(DateTime dateTime) {
    return _dateTimeFormat.format(dateTime);
  }

  /// Format time to string
  static String formatTime(DateTime dateTime) {
    return _timeFormat.format(dateTime);
  }

  /// Parse string to date
  static DateTime? parseDate(String dateString) {
    try {
      return _dateFormat.parse(dateString);
    } on FormatException {
      return null;
    }
  }

  /// Parse string to date and time
  static DateTime? parseDateTime(String dateTimeString) {
    try {
      return _dateTimeFormat.parse(dateTimeString);
    } on FormatException {
      return null;
    }
  }
}
