/// Interface for real-time networking (e.g., WebSockets)
abstract class IRealtimeClient {
  /// Stream of incoming real-time messages
  Stream<dynamic> get stream;

  /// Connection state
  bool get isConnected;

  /// Connect to a given websocket or socket url
  Future<void> connect(String url);

  /// Disconnect and cleanup resources
  void disconnect();

  /// Send data to the real-time server
  void send(dynamic data);
}
