import 'dart:async';

import 'package:flutter_starter/core/network/realtime/i_realtime_client.dart';
import 'package:logger/logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A raw WebSocket implementation of [IRealtimeClient] using
/// `web_socket_channel` package.
class RawWebSocketClientImpl implements IRealtimeClient {
  final Logger _logger = Logger();
  WebSocketChannel? _channel;
  final _streamController = StreamController<dynamic>.broadcast();

  @override
  Stream<dynamic> get stream => _streamController.stream;

  @override
  bool get isConnected => _channel != null;

  @override
  Future<void> connect(String url) async {
    if (isConnected) disconnect();

    try {
      _logger.d('Connecting to WebSocket at: $url');
      _channel = WebSocketChannel.connect(Uri.parse(url));

      _channel!.stream.listen(
        _streamController.add,
        onError: (Object error) {
          _logger.e('WebSocket Error: $error');
          _streamController.addError(error);
          disconnect();
        },
        onDone: () {
          _logger.d('WebSocket connection closed.');
          disconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      _logger.e('Failed to initiate WebSocket connection: $e');
      rethrow;
    }
  }

  @override
  void send(dynamic data) {
    if (!isConnected) {
      _logger.w('Cannot send data. WebSocket is not connected.');
      return;
    }
    _channel!.sink.add(data);
  }

  @override
  void disconnect() {
    unawaited(_channel?.sink.close());
    _channel = null;
    _logger.d('Disconnected from WebSocket.');
  }
}
