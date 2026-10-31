// Throttler compared DateTime.now() differences, so a backward step of the
// system clock (NTP, the user changing the time) made the difference
// negative and suppressed every call until the clock caught up - hours,
// possibly. It now measures time monotonically; the test drives that source.

import 'package:flutter_starter/core/utils/debouncer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calls are spaced by elapsed monotonic time, whatever the wall clock '
      'does', () {
    var elapsed = Duration.zero;
    final throttler = Throttler(
      duration: const Duration(milliseconds: 100),
      elapsed: () => elapsed,
    );
    var calls = 0;

    throttler.run(() => calls++);
    expect(calls, 1);

    elapsed = const Duration(milliseconds: 50);
    throttler.run(() => calls++);
    expect(calls, 1, reason: 'within the duration');

    // Whatever the wall clock did meanwhile (a backward step included), 100ms
    // have passed on the monotonic clock: the call runs.
    elapsed = const Duration(milliseconds: 100);
    throttler.run(() => calls++);
    expect(calls, 2);
  });

  test('the default source is a running stopwatch', () async {
    final throttler = Throttler(duration: const Duration(milliseconds: 20));
    var calls = 0;

    throttler
      ..run(() => calls++)
      ..run(() => calls++);
    expect(calls, 1);

    await Future<void>.delayed(const Duration(milliseconds: 40));
    throttler.run(() => calls++);
    expect(calls, 2);
  });
}
