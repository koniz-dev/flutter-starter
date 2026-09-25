import 'package:intl/intl.dart';

/// Date formatting utilities
///
/// ## Two pairs, two contracts
///
/// [formatDate] / [formatDateTime] / [formatTime] write **wall-clock digits
/// with no timezone marker**, and [parseDate] / [parseDateTime] read them
/// back as **local** time. That pair is for displaying and re-reading a date
/// a human typed; it is lossy for a UTC [DateTime], because the marker that
/// says "this was UTC" is not written. Formatting
/// `DateTime.utc(2024, 1, 15, 14, 30, 45)` yields `'2024-01-15 14:30:45'`,
/// and parsing that back on a UTC+7 device yields a local `DateTime` whose
/// `.toUtc()` is `07:30:45Z` - a seven-hour error.
///
/// [formatIso8601] / [parseIso8601] are the pair to use for anything stored,
/// transmitted, or compared. They always round trip through UTC and always
/// carry the `Z` designator, so no instant shifts.
///
/// ## Strict parsing
///
/// Every `parse*` method rejects out-of-range calendar fields instead of
/// rolling them over. `parseDate('2024-02-30')` and `parseDate('2024-13-01')`
/// both return `null` rather than 1 March 2024 and 1 January 2025.
class DateFormatter {
  DateFormatter._();

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final DateFormat _timeFormat = DateFormat('HH:mm:ss');

  /// Leading `yyyy-MM-dd` of an ISO-8601 string.
  static final RegExp _iso8601Date = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');

  /// Format date to string as `yyyy-MM-dd`, in the wall clock of [date].
  ///
  /// No timezone marker is written. See the class doc for when to prefer
  /// [formatIso8601].
  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }

  /// Format date and time to string as `yyyy-MM-dd HH:mm:ss`, in the wall
  /// clock of [dateTime].
  ///
  /// No timezone marker is written. See the class doc for when to prefer
  /// [formatIso8601].
  static String formatDateTime(DateTime dateTime) {
    return _dateTimeFormat.format(dateTime);
  }

  /// Format time to string as `HH:mm:ss`, in the wall clock of [dateTime].
  static String formatTime(DateTime dateTime) {
    return _timeFormat.format(dateTime);
  }

  /// Parse a `yyyy-MM-dd` string into a **local** [DateTime].
  ///
  /// Returns null when [dateString] is not exactly that shape or carries an
  /// out-of-range field: `'2024-02-30'` and `'2024-13-01'` both return null.
  static DateTime? parseDate(String dateString) {
    try {
      return _dateFormat.parseStrict(dateString);
    } on FormatException {
      return null;
    }
  }

  /// Parse a `yyyy-MM-dd HH:mm:ss` string into a **local** [DateTime].
  ///
  /// Returns null when [dateTimeString] is not exactly that shape or carries
  /// an out-of-range field.
  static DateTime? parseDateTime(String dateTimeString) {
    try {
      return _dateTimeFormat.parseStrict(dateTimeString);
    } on FormatException {
      return null;
    }
  }

  /// Format [dateTime] as an ISO-8601 string in UTC, always ending in `Z`.
  ///
  /// This is the lossless counterpart of [parseIso8601]: any [DateTime],
  /// local or UTC, survives `parseIso8601(formatIso8601(d))` as the same
  /// instant.
  static String formatIso8601(DateTime dateTime) {
    return dateTime.toUtc().toIso8601String();
  }

  /// Parse an ISO-8601 string into a **UTC** [DateTime].
  ///
  /// Accepts any form [DateTime.parse] accepts, including an explicit `Z` or
  /// a numeric offset, and normalises the result to UTC. A string with no
  /// timezone designator is read as local time and then converted, matching
  /// [DateTime.parse].
  ///
  /// Returns null when the string does not parse, or when its calendar date
  /// is out of range. [DateTime.parse] rolls `2024-02-30` over to 1 March;
  /// this method returns null instead.
  static DateTime? parseIso8601(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;

    final match = _iso8601Date.firstMatch(value);
    if (match != null) {
      final year = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final day = int.parse(match.group(3)!);
      // DateTime.utc rolls out-of-range fields over, so a mismatch after
      // construction means the input field was out of range.
      final probe = DateTime.utc(year, month, day);
      if (probe.year != year || probe.month != month || probe.day != day) {
        return null;
      }
    }

    return parsed.toUtc();
  }
}
