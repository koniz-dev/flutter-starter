// A staging or production release refuses a BASE_URL that is not https, but
// the realtime client connected to any scheme, so a ws:// URL sent the
// realtime token and every message in cleartext, where pinning cannot apply.
// Values are fed through a `.env` asset, as in release_without_https_test.dart.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/config/env_config.dart';
import 'package:flutter_starter/core/network/realtime/raw_websocket_client.dart';
import 'package:flutter_starter/core/network/ssl_pinning.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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

  tearDownAll(() async {
    await loadEnv('development');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(_assetChannel, null);
  });

  late List<Uri> opened;

  /// Records the URI and fails fast against a port nothing listens on.
  WebSocketChannel recordingConnector(Uri uri, HttpClient? _) {
    opened.add(uri);
    return WebSocketChannel.connect(Uri.parse('ws://127.0.0.1:1'));
  }

  RawWebSocketClientImpl client({required bool releaseMode}) =>
      RawWebSocketClientImpl(
        sslPinning: const SslPinning(enabled: false, fingerprints: []),
        connectChannel: recordingConnector,
        releaseMode: releaseMode,
      );

  setUp(() => opened = []);

  for (final environment in ['staging', 'production']) {
    group('a $environment release', () {
      setUp(() => loadEnv(environment));

      for (final url in [
        'ws://realtime.example.com/socket',
        'http://realtime.example.com/socket',
        '/socket',
        'realtime.example.com/socket',
      ]) {
        test('refuses $url and opens nothing', () async {
          await expectLater(
            client(releaseMode: true).connect(url),
            throwsA(isA<WebSocketChannelException>()),
          );
          expect(opened, isEmpty);
        });
      }

      test('refuses an unparsable URL and opens nothing', () async {
        await expectLater(
          client(releaseMode: true).connect('ws://[bad'),
          throwsA(isA<FormatException>()),
        );
        expect(opened, isEmpty);
      });

      test('connects to wss://', () async {
        await client(releaseMode: true)
            .connect('wss://realtime.example.com/socket')
            .catchError((Object _) {});
        expect(opened, hasLength(1));
      });

      test('a debug or profile build still connects to ws://', () async {
        await client(releaseMode: false)
            .connect('ws://realtime.example.com/socket')
            .catchError((Object _) {});
        expect(opened, hasLength(1));
      });

      test('a refused URL keeps the current connection', () async {
        final live = client(releaseMode: true);
        await live
            .connect('wss://realtime.example.com/socket')
            .catchError((Object _) {});
        // The fake handshake to a closed port fails, so open a pending one
        // and check it is not cancelled by the refused connect.
        final pending = live.connect('wss://realtime.example.com/again');
        await expectLater(
          live.connect('ws://realtime.example.com/socket'),
          throwsA(isA<WebSocketChannelException>()),
        );
        await expectLater(
          pending,
          throwsA(
            isA<WebSocketChannelException>().having(
              (e) => '$e',
              'message',
              isNot(contains('cancelled')),
            ),
          ),
        );
      });

      test('the refusal names the URL redacted', () async {
        Object? error;
        try {
          await client(
            releaseMode: true,
          ).connect('ws://user:pass@host.example.com/socket?token=SECRET');
        } on Object catch (e) {
          error = e;
        }
        final message = '$error';
        expect(message, contains('host.example.com'));
        for (final secret in ['user', 'pass', 'SECRET']) {
          expect(message, isNot(contains(secret)), reason: secret);
        }
      });
    });
  }

  test('a development release still connects to ws://', () async {
    await loadEnv('development');
    await client(releaseMode: true)
        .connect('ws://10.0.2.2:3000/socket')
        .catchError((Object _) {});
    expect(opened, hasLength(1));
  });
}
