import 'dart:async';
import 'package:flutter/foundation.dart';

/// Utility class for debouncing function calls
///
/// Debouncing ensures that a function is only called after a certain
/// amount of time has passed since it was last invoked. This is useful
/// for search inputs, API calls, and other operations that should not
/// be executed too frequently.
///
/// Example:
/// ```dart
/// final debouncer = Debouncer(duration: Duration(milliseconds: 500));
///
/// // In a TextField's onChanged callback:
/// onChanged: (value) {
///   debouncer.run(() {
///     // This will only execute 500ms after the user stops typing
///     performSearch(value);
///   });
/// }
/// ```
class Debouncer {
  /// Creates a [Debouncer] with the given [duration]
  ///
  /// [duration] - The duration to wait before executing the callback
  Debouncer({required Duration duration}) : _duration = duration;

  final Duration _duration;
  Timer? _timer;

  /// Executes the callback after the debounce duration
  ///
  /// If called multiple times before the duration expires,
  /// the previous timer is cancelled and a new one is started.
  void run(VoidCallback callback) {
    _timer?.cancel();
    _timer = Timer(_duration, callback);
  }

  /// Cancels any pending callback execution
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Disposes the debouncer and cancels any pending callbacks
  void dispose() {
    cancel();
  }
}

/// Utility class for throttling function calls
///
/// Throttling ensures that a function is called at most once per
/// specified duration. This is useful for scroll events, resize events,
/// and other operations that should be limited in frequency.
///
/// Example:
/// ```dart
/// final throttler = Throttler(duration: Duration(milliseconds: 100));
///
/// // In a scroll listener:
/// onScroll: () {
///   throttler.run(() {
///     // This will execute at most once every 100ms
///     updateScrollPosition();
///   });
/// }
/// ```
class Throttler {
  /// Creates a [Throttler] with the given [duration]
  ///
  /// [duration] - The minimum duration between function calls
  Throttler({required Duration duration}) : _duration = duration;

  final Duration _duration;
  DateTime? _lastRun;

  /// Executes the callback if enough time has passed since the last execution
  ///
  /// If called before the duration expires, the callback is ignored.
  void run(VoidCallback callback) {
    final now = DateTime.now();
    if (_lastRun == null || now.difference(_lastRun!) >= _duration) {
      _lastRun = now;
      callback();
    }
  }

  /// Resets the throttler, allowing immediate execution
  void reset() {
    _lastRun = null;
  }
}
