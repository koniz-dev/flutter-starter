// The WebSocket handshake follows the same certificate pinning policy as
// ApiClient. It used to call WebSocketChannel.connect with no client, so a
// `wss://` connection trusted every certificate the platform does whatever
// API_SSL_FINGERPRINTS said.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_starter/core/network/realtime/raw_websocket_client.dart';
import 'package:flutter_starter/core/network/ssl_pinning.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  late List<HttpClient?> clients;

  /// Records the client the handshake would go through, and returns a
  /// channel to a port nothing listens on, so connect() fails fast.
  WebSocketChannel recordingConnector(Uri uri, HttpClient? pinnedClient) {
    clients.add(pinnedClient);
    return WebSocketChannel.connect(Uri.parse('ws://127.0.0.1:1'));
  }

  Future<void> connectOnce(RawWebSocketClientImpl client) async {
    try {
      await client.connect('wss://realtime.example.com/socket');
    } on Object catch (_) {
      // The fake endpoint refuses; only the transport choice matters here.
    }
  }

  setUp(() => clients = []);

  test('with pinning in effect the handshake goes through a pinned client, '
      'a fresh one per connection', () async {
    final pinning = SslPinning(enabled: true, fingerprints: ['a' * 64]);
    expect(pinning.isEffective, isTrue);
    final client = RawWebSocketClientImpl(
      sslPinning: pinning,
      connectChannel: recordingConnector,
    );

    await connectOnce(client);
    await connectOnce(client);

    expect(clients, hasLength(2));
    expect(clients, everyElement(isA<HttpClient>()));
    expect(identical(clients[0], clients[1]), isFalse);
  });

  test('with pinning off the default transport is used', () async {
    final client = RawWebSocketClientImpl(
      sslPinning: const SslPinning(enabled: false, fingerprints: []),
      connectChannel: recordingConnector,
    );

    await connectOnce(client);

    expect(clients, [null]);
  });

  test('pinning requested without fingerprints pins nothing, as for the API '
      'client', () async {
    final client = RawWebSocketClientImpl(
      sslPinning: const SslPinning(enabled: true, fingerprints: []),
      connectChannel: recordingConnector,
    );

    // createHttpClient trips the same misconfiguration assert as
    // createAdapter in debug; the test VM runs with asserts on.
    await expectLater(
      () => client.connect('wss://realtime.example.com/socket'),
      throwsA(isA<AssertionError>()),
    );
    expect(clients, isEmpty);
  });

  test('createHttpClient and createAdapter agree on when pinning applies', () {
    for (final pinning in [
      SslPinning(enabled: true, fingerprints: ['a' * 64]),
      const SslPinning(enabled: false, fingerprints: []),
      SslPinning(enabled: false, fingerprints: ['a' * 64]),
    ]) {
      expect(
        pinning.createHttpClient() != null,
        pinning.createAdapter() != null,
        reason:
            'enabled=${pinning.enabled} '
            'fingerprints=${pinning.fingerprints.length}',
      );
    }
  });

  // End to end, against a real TLS WebSocket server on loopback with a
  // throwaway self-signed certificate: the pinned handshake must refuse a
  // certificate the fingerprints do not name, and accept the one they do.
  group(
    'a real wss:// handshake',
    () {
      late Directory dir;
      late HttpServer server;
      late String fingerprint;
      late String url;

      setUpAll(() async {
        dir = Directory.systemTemp.createTempSync('ws_pinning_');
        final made = Process.runSync('openssl', [
          'req',
          '-x509',
          '-newkey',
          'rsa:2048',
          '-nodes',
          '-days',
          '1',
          '-subj',
          '/CN=127.0.0.1',
          '-keyout',
          '${dir.path}/key.pem',
          '-out',
          '${dir.path}/cert.pem',
        ]);
        expect(made.exitCode, 0, reason: '${made.stderr}');
        final pem = File('${dir.path}/cert.pem').readAsStringSync();
        final body = pem
            .split('\n')
            .where((l) => l.isNotEmpty && !l.startsWith('-----'))
            .join();
        fingerprint = sha256.convert(base64.decode(body)).toString();

        final context = SecurityContext()
          ..useCertificateChain('${dir.path}/cert.pem')
          ..usePrivateKey('${dir.path}/key.pem');
        server =
            await HttpServer.bindSecure(
                InternetAddress.loopbackIPv4,
                0,
                context,
              )
              ..listen((request) async {
                final socket = await WebSocketTransformer.upgrade(request);
                socket.listen(socket.add);
              });
        url = 'wss://127.0.0.1:${server.port}';
      });

      tearDownAll(() async {
        await server.close(force: true);
        dir.deleteSync(recursive: true);
      });

      test('a certificate the fingerprints do not name is refused', () async {
        final client = RawWebSocketClientImpl(
          sslPinning: SslPinning(enabled: true, fingerprints: ['0' * 64]),
        );

        await expectLater(client.connect(url), throwsA(anything));
        expect(client.isConnected, isFalse);
      });

      test('the pinned certificate is accepted', () async {
        final client = RawWebSocketClientImpl(
          sslPinning: SslPinning(enabled: true, fingerprints: [fingerprint]),
        );

        await client.connect(url);
        expect(client.isConnected, isTrue);
        client.disconnect();
      });

      test('without pinning, the self-signed certificate is refused by the '
          'platform trust store', () async {
        final client = RawWebSocketClientImpl(
          sslPinning: const SslPinning(enabled: false, fingerprints: []),
        );

        await expectLater(client.connect(url), throwsA(anything));
      });
    },
    skip: Process.runSync('which', ['openssl']).exitCode == 0
        ? false
        : 'openssl is not installed',
  );
}
