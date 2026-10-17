// parseIso8601 must reject out-of-range fields in every form it accepts
// (koniz-dev/flutter-starter#325).
//
// The #63 check only matched the dashed date prefix and never the time, so
// the basic form 20260230 still rolled over to 1 March and T25:61 into the
// next day. CacheInterceptor (entry age) and TaskModel depend on this.

import 'package:flutter_starter/core/utils/date_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('criterion 1: out-of-range fields return null', () {
    for (final value in const [
      '20260230',
      '2026-01-01T25:00:00Z',
      '2026-01-01T23:61:00Z',
      // Same defects through the other spellings.
      '2026-02-30',
      '20260230T120000Z',
      '2026-01-01T23:59:61Z',
      '20260101T2500Z',
    ]) {
      test(value, () => expect(DateFormatter.parseIso8601(value), isNull));
    }
  });

  group('criterion 2: valid forms parse to the correct UTC instant', () {
    final expected = DateTime.utc(2026, 2, 28, 13, 45, 30);
    for (final value in const [
      '2026-02-28T13:45:30Z',
      '20260228T134530Z',
      '2026-02-28T15:45:30+02:00',
      '20260228T154530+0200',
      '2026-02-28T08:45:30-05:00',
    ]) {
      test(value, () {
        final parsed = DateFormatter.parseIso8601(value);
        expect(parsed, expected);
        expect(parsed!.isUtc, isTrue);
      });
    }

    test('a date-only value in either form', () {
      final local = DateTime(2026, 2, 28).toUtc();
      expect(DateFormatter.parseIso8601('2026-02-28'), local);
      expect(DateFormatter.parseIso8601('20260228'), local);
    });

    test('the edges of the ranges are accepted', () {
      expect(
        DateFormatter.parseIso8601('2024-02-29T23:59:59Z'),
        DateTime.utc(2024, 2, 29, 23, 59, 59),
      );
      expect(
        DateFormatter.parseIso8601('2026-01-01T00:00:00Z'),
        DateTime.utc(2026),
      );
    });

    test('formatIso8601 still round-trips', () {
      final now = DateTime.now();
      expect(
        DateFormatter.parseIso8601(DateFormatter.formatIso8601(now)),
        now.toUtc(),
      );
    });
  });
}
