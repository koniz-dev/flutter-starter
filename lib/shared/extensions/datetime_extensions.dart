/// DateTime extension methods
extension DateTimeExtensions on DateTime {
  /// Whether this date is today in the receiver's UTC or local zone.
  bool get isToday => _isSameDay(_inReceiverZone(DateTime.now()));

  /// Check if date is yesterday
  bool get isYesterday => isYesterdayRelativeTo(DateTime.now());

  /// Check if date is tomorrow
  bool get isTomorrow => isTomorrowRelativeTo(DateTime.now());

  /// Whether this date is the calendar day before [now] in this date's zone.
  ///
  /// Calendar arithmetic, not `now - 24h`: around a daylight-saving change a
  /// day lasts 23 or 25 hours, and subtracting 24 hours landed on the wrong
  /// date for an hour.
  bool isYesterdayRelativeTo(DateTime now) => _isRelativeDay(now, -1);

  /// Whether this date is the calendar day after [now] in this date's zone; see
  /// [isYesterdayRelativeTo].
  bool isTomorrowRelativeTo(DateTime now) => _isRelativeDay(now, 1);

  bool _isRelativeDay(DateTime now, int offset) {
    final reference = _inReceiverZone(now);
    return _isSameDay(
      _calendarDay(reference.year, reference.month, reference.day + offset),
    );
  }

  DateTime _inReceiverZone(DateTime value) =>
      isUtc ? value.toUtc() : value.toLocal();

  DateTime _calendarDay(int year, int month, int day) =>
      isUtc ? DateTime.utc(year, month, day) : DateTime(year, month, day);

  bool _isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  /// Start of the calendar day, preserving the receiver's UTC or local zone.
  DateTime get startOfDay => _calendarDay(year, month, day);

  /// End of the calendar day, preserving the receiver's UTC or local zone.
  DateTime get endOfDay => isUtc
      ? DateTime.utc(year, month, day, 23, 59, 59, 999)
      : DateTime(year, month, day, 23, 59, 59, 999);

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
