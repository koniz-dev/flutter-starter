import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/network/interceptors/api_logging_interceptor.dart';
import 'package:flutter_starter/core/network/realtime/i_realtime_client.dart';

/// A no-op implementation of [IRealtimeClient] for testing or disabling
/// real-time networking.
///
/// It is the default `realtimeClientProvider`, so realtime code written
/// before a real client is wired runs against it - URLs carrying a token
/// (`wss://host/socket?token=...`) and real payloads included. What it
/// prints is therefore limited: nothing outside debug builds, and in debug
/// the URL redacted by the HTTP logs' key rules and only the *type* of a
/// sent payload, never its content.
class NoOpRealtimeClient implements IRealtimeClient {
  final _controller = StreamController<dynamic>.broadcast();

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  bool get isConnected => false;

  @override
  Future<void> connect(String url) async {
    _debugPrint(
      'Simulated connection to ${ApiLoggingInterceptor.redactPath(url)}',
    );
  }

  @override
  void disconnect() {
    _debugPrint('Simulated disconnection');
  }

  @override
  void send(dynamic data) {
    _debugPrint('Simulated send of a ${data.runtimeType}');
  }

  /// `debugPrint` has no release guard of its own.
  static void _debugPrint(String message) {
    if (kDebugMode) debugPrint('NoOpRealtimeClient: $message');
  }
}
