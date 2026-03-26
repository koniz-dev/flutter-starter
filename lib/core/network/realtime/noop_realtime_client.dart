import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/network/realtime/i_realtime_client.dart';

/// A no-op implementation of [IRealtimeClient] for testing or disabling
/// real-time networking.
class NoOpRealtimeClient implements IRealtimeClient {
  final _controller = StreamController<dynamic>.broadcast();

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  bool get isConnected => false;

  @override
  Future<void> connect(String url) async {
    debugPrint('NoOpRealtimeClient: Simulated connection to $url');
  }

  @override
  void disconnect() {
    debugPrint('NoOpRealtimeClient: Simulated disconnection');
  }

  @override
  void send(dynamic data) {
    debugPrint('NoOpRealtimeClient: Simulated send -> $data');
  }
}
