/// Signals that a previously open realtime connection was closed by its peer.
///
/// The stream stays open so subscribers can observe a later reconnection.
class RealtimeConnectionClosed implements Exception {
  /// Creates a close event with the transport's optional close [code].
  const RealtimeConnectionClosed(this.code);

  /// The peer's close code, or null if the transport supplied none.
  final int? code;

  @override
  String toString() => 'Realtime connection closed (code: $code)';
}

/// Interface for real-time networking (e.g., WebSockets)
abstract class IRealtimeClient {
  /// Stream of incoming real-time messages and established-connection errors.
  ///
  /// A remote close, including a clean close, emits [RealtimeConnectionClosed]
  /// after [isConnected] becomes false. Install an error handler to observe it.
  /// The stream remains open for reconnects; an intentional [disconnect] does
  /// not emit a remote-close error.
  Stream<dynamic> get stream;

  /// Connection state
  bool get isConnected;

  /// Connect to a given websocket or socket url.
  ///
  /// Error contract every implementation must meet:
  ///
  /// - If the connection cannot be established (unreachable host, refused
  ///   port, failed handshake), the returned future completes with that
  ///   error. It must not complete normally for a connection that never
  ///   opened.
  /// - The attempt is bounded: an implementation must fail with a
  ///   `TimeoutException` after a finite, documented connect timeout rather
  ///   than wait for the operating system's TCP timeout.
  /// - Calling [disconnect], or [connect] again, while an attempt is still
  ///   in flight cancels it: the cancelled future completes with an error
  ///   and its connection is closed, never adopted. At most one connection
  ///   is open at a time.
  /// - When the future completes with an error, [isConnected] is already
  ///   `false` on the next line - callers need no delay to observe it.
  /// - A connection failure must surface only through the returned future;
  ///   it must never escape as an unhandled asynchronous error.
  /// - Errors on an already-open connection are delivered on [stream], after
  ///   which [isConnected] becomes `false`.
  ///
  /// When the future completes normally, [isConnected] is `true` unless the
  /// implementation never connects at all (for example a no-op client).
  Future<void> connect(String url);

  /// Disconnect and cleanup resources
  void disconnect();

  /// Send data to the real-time server
  void send(dynamic data);
}
