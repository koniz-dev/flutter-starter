import 'package:flutter_starter/core/utils/debouncer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Debouncer', () {
    test('should create instance with duration', () {
      const duration = Duration(milliseconds: 500);
      final debouncer = Debouncer(duration: duration);

      expect(debouncer, isNotNull);
    });

    test('should execute callback after duration', () async {
      var executed = false;
      // Variable is used via cascade operators, but linter doesn't recognize it
      // ignore: unused_local_variable
      final debouncer = Debouncer(duration: const Duration(milliseconds: 100))
        ..run(() {
          executed = true;
        });

      expect(executed, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(executed, isTrue);
    });

    test('should cancel previous callback when run multiple times', () async {
      var callCount = 0;
      final debouncer = Debouncer(duration: const Duration(milliseconds: 100))
        ..run(() {
          callCount++;
        });

      await Future<void>.delayed(const Duration(milliseconds: 50));
      debouncer.run(() {
        callCount++;
      });

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(callCount, 1);
    });

    test('should cancel pending callback', () async {
      var executed = false;
      // Variable is used via cascade operators, but linter doesn't recognize it
      // ignore: unused_local_variable
      final debouncer = Debouncer(duration: const Duration(milliseconds: 100))
        ..run(() {
          executed = true;
        })
        ..cancel();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(executed, isFalse);
    });

    test('should dispose and cancel pending callbacks', () async {
      var executed = false;
      // Variable is used via cascade operators, but linter doesn't recognize it
      // ignore: unused_local_variable
      final debouncer = Debouncer(duration: const Duration(milliseconds: 100))
        ..run(() {
          executed = true;
        })
        ..dispose();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(executed, isFalse);
    });

    test('should handle multiple rapid calls', () async {
      var callCount = 0;
      final debouncer = Debouncer(duration: const Duration(milliseconds: 100));

      for (var i = 0; i < 10; i++) {
        debouncer.run(() {
          callCount++;
        });
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(callCount, 1);
    });

    test('should handle zero duration', () async {
      var executed = false;
      // Variable is used via cascade operators, but linter doesn't recognize it
      // ignore: unused_local_variable
      final debouncer = Debouncer(duration: Duration.zero)
        ..run(() {
          executed = true;
        });

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(executed, isTrue);
    });

    test('should handle very long duration', () async {
      var executed = false;
      // Variable is used via cascade operators, but linter doesn't recognize it
      // ignore: unused_local_variable
      final debouncer = Debouncer(duration: const Duration(seconds: 1))
        ..run(() {
          executed = true;
        });

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(executed, isFalse);
    });
  });

  group('Throttler', () {
    test('should create instance with duration', () {
      const duration = Duration(milliseconds: 100);
      final throttler = Throttler(duration: duration);

      expect(throttler, isNotNull);
    });

    test('should execute callback immediately on first call', () {
      var executed = false;
      // Variable is used via cascade operators, but linter doesn't recognize it
      // ignore: unused_local_variable
      final throttler = Throttler(duration: const Duration(milliseconds: 100))
        ..run(() {
          executed = true;
        });

      expect(executed, isTrue);
    });

    test('should throttle rapid calls', () {
      var callCount = 0;
      // Variable is used via cascade operators, but linter doesn't recognize it
      // ignore: unused_local_variable
      final throttler = Throttler(duration: const Duration(milliseconds: 100))
        ..run(() {
          callCount++;
        })
        ..run(() {
          callCount++;
        })
        ..run(() {
          callCount++;
        });

      expect(callCount, 1);
    });

    test('should allow execution after duration', () async {
      var callCount = 0;
      final throttler = Throttler(duration: const Duration(milliseconds: 50))
        ..run(() {
          callCount++;
        });

      await Future<void>.delayed(const Duration(milliseconds: 100));
      throttler.run(() {
        callCount++;
      });

      expect(callCount, 2);
    });

    test('should reset and allow immediate execution', () {
      var callCount = 0;
      final throttler = Throttler(duration: const Duration(milliseconds: 100))
        ..run(() {
          callCount++;
        })
        ..run(() {
          callCount++;
        });
      expect(callCount, 1);

      throttler
        ..reset()
        ..run(() {
          callCount++;
        });
      expect(callCount, 2);
    });

    test('should handle zero duration', () {
      var callCount = 0;
      // Variable is used via cascade operators, but linter doesn't recognize it
      // ignore: unused_local_variable
      final throttler = Throttler(duration: Duration.zero)
        ..run(() {
          callCount++;
        })
        ..run(() {
          callCount++;
        });

      expect(callCount, 2);
    });

    test('should handle multiple calls with reset', () {
      var callCount = 0;
      // Variable is used via cascade operators, but linter doesn't recognize it
      // ignore: unused_local_variable
      final throttler = Throttler(duration: const Duration(milliseconds: 100))
        ..run(() {
          callCount++;
        })
        ..reset()
        ..run(() {
          callCount++;
        })
        ..reset()
        ..run(() {
          callCount++;
        });

      expect(callCount, 3);
    });
  });
}
