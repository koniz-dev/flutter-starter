// A release refuses a ws:// URL, but dart:io follows a redirect during the
// WebSocket handshake: a wss:// server answering `302 -> http://...` moved
// the connection to cleartext, token and messages included. In a staging or
// production release the handshake now refuses any hop that is not TLS.
//
// Runs against real loopback servers: a TLS one with a throwaway certificate
// (pinned, so the self-signed certificate is accepted) and a plaintext one.

@TestOn('!windows')
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_starter/core/config/env_config.dart';
import 'package:flutter_starter/core/network/realtime/raw_websocket_client.dart';
import 'package:flutter_starter/core/network/ssl_pinning.dart';
import 'package:flutter_test/flutter_test.dart';

const _assetChannel = 'flutter/assets';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var loads = 0;
  Future<void> loadEnv(String environment) async {
    final name = 'env_${loads++}';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(_assetChannel, (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key != name) return null;
          final bytes = Uint8List.fromList(
            utf8.encode('ENVIRONMENT=$environment\n'),
          );
          return ByteData.view(bytes.buffer);
        });
    await EnvConfig.load(fileName: name);
  }

  late Directory dir;
  late HttpServer secure;
  late HttpServer secureTarget;
  late HttpServer plain;
  late String fingerprint;
  var plainRequests = 0;

  setUpAll(() async {
    // The test binding answers every HttpClient request with 400; these
    // tests need real loopback connections.
    HttpOverrides.global = null;
    dir = Directory.systemTemp.createTempSync('ws_redirect_');
    final made = Process.runSync('openssl', [
      'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1', //
      '-subj', '/CN=127.0.0.1',
      '-keyout', '${dir.path}/key.pem',
      '-out', '${dir.path}/cert.pem',
    ]);
    expect(made.exitCode, 0, reason: '${made.stderr}');
    final body = File('${dir.path}/cert.pem')
        .readAsStringSync()
        .split('\n')
        .where((l) => l.isNotEmpty && !l.startsWith('-----'))
        .join();
    fingerprint = sha256.convert(base64.decode(body)).toString();

    plain = await HttpServer.bind(InternetAddress.loopbackIPv4, 0)
      ..listen((request) async {
        plainRequests++;
        final socket = await WebSocketTransformer.upgrade(request);
        socket.add('hello over cleartext');
      });

    final context = SecurityContext()
      ..useCertificateChain('${dir.path}/cert.pem')
      ..usePrivateKey('${dir.path}/key.pem');
    // A redirect target on its own server: dart:io's handshake fails a
    // redirect back to the same TLS server, with or without this change.
    secureTarget =
        await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, context)
          ..listen((request) async {
            final socket = await WebSocketTransformer.upgrade(request);
            socket.add('hello over tls');
          });
    secure =
        await HttpServer.bindSecure(
            InternetAddress.loopbackIPv4,
            0,
            context,
          )
          ..listen((request) async {
            switch (request.uri.path) {
              case '/to-cleartext':
                await request.response.redirect(
                  Uri.parse('http://127.0.0.1:${plain.port}/socket?token=NEXT'),
                );
              case '/to-tls':
                await request.response.redirect(
                  Uri.parse('https://127.0.0.1:${secureTarget.port}/socket'),
                );
              default:
                final socket = await WebSocketTransformer.upgrade(request);
                socket.add('hello over tls');
            }
          });
  });

  tearDownAll(() async {
    await secure.close(force: true);
    await secureTarget.close(force: true);
    await plain.close(force: true);
    dir.deleteSync(recursive: true);
    await loadEnv('development');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(_assetChannel, null);
  });

  setUp(() => plainRequests = 0);

  RawWebSocketClientImpl client({required bool releaseMode}) =>
      RawWebSocketClientImpl(
        sslPinning: SslPinning(enabled: true, fingerprints: [fingerprint]),
        releaseMode: releaseMode,
      );

  String wss(String path) => 'wss://127.0.0.1:${secure.port}$path?token=FIRST';

  test('a production release refuses a redirect to cleartext', () async {
    await loadEnv('production');
    final realtime = client(releaseMode: true);
    final received = <dynamic>[];
    final subscription = realtime.stream.listen(received.add);
    addTearDown(subscription.cancel);

    Object? error;
    try {
      await realtime.connect(wss('/to-cleartext'));
    } on Object catch (e) {
      error = e;
    }

    expect(error, isNotNull);
    expect(realtime.isConnected, isFalse);
    expect(plainRequests, 0, reason: 'nothing reached the cleartext server');
    expect(received, isEmpty);
    expect('$error', isNot(contains('FIRST')));
    expect('$error', isNot(contains('NEXT')));
  });

  test(
    'a production release still follows a redirect that stays on TLS',
    () async {
      await loadEnv('production');
      final realtime = client(releaseMode: true);
      addTearDown(realtime.disconnect);

      await realtime.connect(wss('/to-tls'));

      expect(realtime.isConnected, isTrue);
    },
  );

  test('a debug build follows the redirect as before', () async {
    await loadEnv('production');
    final realtime = client(releaseMode: false);
    addTearDown(realtime.disconnect);

    await realtime.connect(wss('/to-cleartext'));

    expect(realtime.isConnected, isTrue);
    expect(plainRequests, 1);
  });
}
