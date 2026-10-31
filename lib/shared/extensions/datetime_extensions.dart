/// DateTime extension methods
extension DateTimeExtensions on DateTime {
  /// Check if date is today
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Check if date is yesterday
  bool get isYesterday => isYesterdayRelativeTo(DateTime.now());

  /// Check if date is tomorrow
  bool get isTomorrow => isTomorrowRelativeTo(DateTime.now());

  /// Whether this date is the calendar day before [now]'s.
  ///
  /// Calendar arithmetic, not `now - 24h`: around a daylight-saving change a
  /// day lasts 23 or 25 hours, and subtracting 24 hours landed on the wrong
  /// date for an hour.
  bool isYesterdayRelativeTo(DateTime now) =>
      _isSameDay(DateTime(now.year, now.month, now.day - 1));

  /// Whether this date is the calendar day after [now]'s; see
  /// [isYesterdayRelativeTo].
  bool isTomorrowRelativeTo(DateTime now) =>
      _isSameDay(DateTime(now.year, now.month, now.day + 1));

  bool _isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  /// Get start of day
  DateTime get startOfDay {
    return DateTime(year, month, day);
  }

  /// Get end of day
  DateTime get endOfDay {
    return DateTime(year, month, day, 23, 59, 59, 999);
  }

  /// Format date to string (yyyy-MM-dd)
  String toDateString() {
    return '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }

  /// Format time to string (HH:mm:ss)
  String toTimeString() {
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}:'
        '${second.toString().padLeft(2, '0')}';
  }

  /// Format date and time to string
  String toDateTimeString() {
    return '${toDateString()} ${toTimeString()}';
  }
}
