import 'dart:async';
import 'dart:io' show HttpClient, Socket;

import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/network/interceptors/api_logging_interceptor.dart';
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
///
/// A staging or production release refuses any URL that is not `wss://`, as
/// `main()` refuses a `BASE_URL` that is not `https`: web and desktop do not
/// block cleartext, and the realtime token and every message would travel
/// unencrypted, where pinning cannot apply. The same release refuses a
/// handshake redirect that leaves TLS (`302 -> http://...`), which dart:io
/// would otherwise follow; a redirect that stays on TLS is followed, pinned
/// like the first hop. On web the browser follows no handshake redirect.
class RawWebSocketClientImpl implements IRealtimeClient {
  /// Creates a client whose [connect] gives up after [connectTimeout].
  ///
  /// [sslPinning] defaults to [SslPinning.fromConfig], the policy `ApiClient`
  /// uses. [connectChannel] and [releaseMode] are seams for tests.
  RawWebSocketClientImpl({
    this.connectTimeout = const Duration(seconds: 10),
    SslPinning? sslPinning,
    WebSocketConnector connectChannel = _connect,
    bool releaseMode = kReleaseMode,
  }) : _sslPinning = sslPinning ?? SslPinning.fromConfig(),
       _connectChannel = connectChannel,
       _releaseMode = releaseMode;

  final bool _releaseMode;

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
  /// - this is a staging or production release and [url] is not `wss://`
  ///   (a `WebSocketChannelException`; nothing is opened, and an existing
  ///   connection is kept);
  /// - [disconnect] or another [connect] is called before the handshake
  ///   finishes (a `WebSocketChannelException`); the abandoned connection is
  ///   closed, never adopted.
  ///
  /// No error escapes as an unhandled async error.
  @override
  Future<void> connect(String url) async {
    // Realtime endpoints often authenticate with a query token
    // (`wss://host/socket?token=...`), sometimes with userinfo. What this
    // class writes or throws - log lines, and every error a caller may
    // forward to crash reporting - uses the redacted URL.
    final safeUrl = ApiLoggingInterceptor.redactUrl(url);

    _logger.d('Connecting to WebSocket at: $safeUrl');
    final Uri uri;
    try {
      uri = Uri.parse(url);
    } on FormatException {
      // Its own message quotes the whole URL.
      throw FormatException('Invalid WebSocket URL: $safeUrl');
    }
    if (_refusesCleartext && uri.scheme.toLowerCase() != 'wss') {
      _logger.e('Refused a non-wss WebSocket URL in a release: $safeUrl');
      throw WebSocketChannelException(
        'Refusing $safeUrl: a ${AppConfig.environment} release connects '
        'only to wss:// URLs',
      );
    }
    // Only a URL that can be opened replaces the current connection: a
    // refused or unparsable one above leaves it alone.
    if (isConnected || _pending != null) disconnect();
    final generation = _generation;
    final channel = _connectChannel(uri, _transport());
    _pending = channel;
    try {
      await channel.ready.timeout(connectTimeout);
    } catch (e, stackTrace) {
      // The type only: dart:io's handshake errors quote the full URL.
      _logger.e(
        'Failed to open WebSocket connection to $safeUrl: '
        '${e.runtimeType}',
      );
      if (identical(_pending, channel)) _pending = null;
      _close(channel);
      if (e is WebSocketChannelException) {
        // dart:io writes the URL - token and userinfo included - into the
        // handshake error ("Connection to '...' was not upgraded", "...,
        // uri = ..."), and WebSocketChannelException copies it into its
        // message and keeps the original as `inner`. Rethrown, that reached
        // any crash report the caller forwards it to. Scrubbing dart:io's
        // text proved unreliable (an apostrophe in a query value ended the
        // match early), so the new exception is built from the redacted URL
        // and the original error's type alone, with no `inner`.
        Error.throwWithStackTrace(
          WebSocketChannelException(
            'Failed to open WebSocket connection to $safeUrl '
            '(${e.inner?.runtimeType ?? e.runtimeType})',
          ),
          stackTrace,
        );
      }
      rethrow;
    }

    if (generation != _generation) {
      _logger.d(
        'WebSocket connection to $safeUrl was superseded; closing it.',
      );
      _close(channel);
      throw WebSocketChannelException(
        'Connection to $safeUrl was cancelled before it opened.',
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

  /// The [HttpClient] the handshake goes through, or null for the default.
  ///
  /// In a staging or production release the handshake must stay on TLS end
  /// to end: dart:io follows a redirect during the WebSocket handshake, so a
  /// `wss://` server answering `302 -> http://...` downgraded the connection
  /// to cleartext. The client's connection factory refuses any hop that is
  /// not `https`, and opens the rest as [SslPinning.secureConnect] does. Web
  /// is left to the browser, which follows no handshake redirect.
  HttpClient? _transport() {
    final pinned = _sslPinning.createHttpClient();
    if (kIsWeb || !_refusesCleartext) return pinned;
    return (pinned ?? HttpClient())
      ..connectionFactory = (uri, proxyHost, proxyPort) {
        if (uri.scheme != 'https') {
          return Future.error(
            WebSocketChannelException(
              'Refusing a cleartext hop to '
              '${ApiLoggingInterceptor.redactUrl(uri.toString())} during the '
              'WebSocket handshake of a ${AppConfig.environment} release',
            ),
          );
        }
        // Through a proxy (HTTPS_PROXY on desktop), dart:io sends CONNECT
        // over this socket and then secures it with the client's own,
        // pinned, context: hand it the plain connection to the proxy.
        if (proxyHost != null && proxyPort != null) {
          return Socket.startConnect(proxyHost, proxyPort);
        }
        return _sslPinning.secureConnect(uri.host, uri.port);
      };
  }

  bool get _refusesCleartext =>
      _releaseMode && (AppConfig.isStaging || AppConfig.isProduction);

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
