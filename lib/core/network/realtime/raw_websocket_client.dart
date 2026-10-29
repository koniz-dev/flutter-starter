import 'dart:async';
import 'dart:io' show HttpClient;

import 'package:flutter_starter/core/network/realtime/i_realtime_client.dart';
import 'package:flutter_starter/core/network/ssl_pinning.dart';
import 'package:logger/logger.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Opens a [WebSocketChannel] to `uri`, through `pinnedClient` when one is
/// given.
typedef WebSocketConnector = WebSocketChannel Function(
  Uri uri,
  HttpClient? pinnedClient,
);

WebSocketChannel _connect(Uri uri, HttpClient? pinnedClient) =>
    pinnedClient == null
    ? WebSocketChannel.connect(uri)
    : IOWebSocketChannel.connect(uri, customClient: pinnedClient);

/// A raw WebSocket implementation of [IRealtimeClient] using
/// `web_socket_channel` package.
///
/// The handshake follows the same certificate pinning policy as `ApiClient`:
/// when [SslPinning.isEffective], the connection goes through the pinned
/// [HttpClient] from [SslPinning.createHttpClient], so a `wss://` URL is
/// refused for any certificate the fingerprints do not name. Otherwise -
/// pinning off, or on web, where the browser owns TLS - it uses the default
/// transport.
class RawWebSocketClientImpl implements IRealtimeClient {
  /// Creates a client whose [connect] gives up after [connectTimeout].
  ///
  /// [sslPinning] defaults to [SslPinning.fromConfig], the policy `ApiClient`
  /// uses. [connectChannel] is a seam for tests.
  RawWebSocketClientImpl({
    this.connectTimeout = const Duration(seconds: 10),
    SslPinning? sslPinning,
    WebSocketConnector connectChannel = _connect,
  }) : _sslPinning = sslPinning ?? SslPinning.fromConfig(),
       _connectChannel = connectChannel;

  final SslPinning _sslPinning;
  final WebSocketConnector _connectChannel;

  /// How long [connect] waits for the WebSocket handshake before it fails
  /// with a [TimeoutException].
  final Duration connectTimeout;

  final Logger _logger = Logger();
  final _streamController = StreamController<dynamic>.broadcast();

  /// The open connection, if any.
  WebSocketChannel? _channel;

  /// A connection whose handshake is still in flight, if any.
  WebSocketChannel? _pending;

  /// Bumped by every [disconnect], so an in-flight [connect] can tell it has
  /// been cancelled or superseded while it was awaiting the handshake.
  int _generation = 0;

  @override
  Stream<dynamic> get stream => _streamController.stream;

  @override
  bool get isConnected => _channel != null;

  /// Opens the connection and completes only once the WebSocket handshake
  /// has succeeded.
  ///
  /// Completes with an error, leaving [isConnected] `false` and emitting
  /// nothing on [stream], when:
  ///
  /// - the server is unreachable or the handshake fails (typically a
  ///   `WebSocketChannelException`);
  /// - the handshake does not finish within [connectTimeout]
  ///   (a [TimeoutException]);
  /// - [disconnect] or another [connect] is called before the handshake
  ///   finishes (a `WebSocketChannelException`); the abandoned connection is
  ///   closed, never adopted.
  ///
  /// No error escapes as an unhandled async error.
  @override
  Future<void> connect(String url) async {
    if (isConnected || _pending != null) disconnect();
    final generation = _generation;

    _logger.d('Connecting to WebSocket at: $url');
    final channel = _connectChannel(
      Uri.parse(url),
      _sslPinning.createHttpClient(),
    );
    _pending = channel;
    try {
      await channel.ready.timeout(connectTimeout);
    } catch (e) {
      _logger.e('Failed to open WebSocket connection: $e');
      if (identical(_pending, channel)) _pending = null;
      _close(channel);
      rethrow;
    }

    if (generation != _generation) {
      _logger.d('WebSocket connection to $url was superseded; closing it.');
      _close(channel);
      throw WebSocketChannelException(
        'Connection to $url was cancelled before it opened.',
      );
    }

    _pending = null;
    _channel = channel;
    channel.stream.listen(
      _streamController.add,
      onError: (Object error) {
        if (!identical(_channel, channel)) return;
        _logger.e('WebSocket Error: $error');
        _streamController.addError(error);
        disconnect();
      },
      onDone: () {
        if (!identical(_channel, channel)) return;
        _logger.d('WebSocket connection closed.');
        disconnect();
      },
      cancelOnError: false,
    );
  }

  @override
  void send(dynamic data) {
    if (!isConnected) {
      _logger.w('Cannot send data. WebSocket is not connected.');
      return;
    }
    _channel!.sink.add(data);
  }

  /// Closes the open connection and cancels any [connect] still awaiting its
  /// handshake.
  @override
  void disconnect() {
    _generation++;
    final open = _channel;
    final pending = _pending;
    _channel = null;
    _pending = null;
    if (open != null) _close(open);
    if (pending != null) _close(pending);
    _logger.d('Disconnected from WebSocket.');
  }

  void _close(WebSocketChannel channel) => channel.sink.close().ignore();
}
