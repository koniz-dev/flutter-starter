import 'dart:async';

/// A handle that cancels an `ApiClient` request, with no dio type in sight.
///
/// Pass one to any `ApiClient` verb and call [cancel] when the result is no
/// longer wanted - a screen disposed, a search superseded by the next
/// keystroke. The caller's future then fails with a `NetworkException` coded
/// `REQUEST_CANCELLED`, and nothing further reaches the transport for that
/// request: not a `RetryInterceptor` re-send, not a 401 refresh's replay
/// (koniz-dev/flutter-starter#316).
///
/// One handle may cover several requests; cancelling it cancels them all.
/// Cancelling twice, or after the requests finished, does nothing.
class RequestCancellation {
  final Completer<String?> _cancelled = Completer<String?>();

  /// Whether [cancel] has been called.
  bool get isCancelled => _cancelled.isCompleted;

  /// Completes with the reason given to [cancel], once it is called.
  Future<String?> get whenCancelled => _cancelled.future;

  /// Cancels every request this handle was passed to.
  void cancel([String? reason]) {
    if (!_cancelled.isCompleted) _cancelled.complete(reason);
  }
}
