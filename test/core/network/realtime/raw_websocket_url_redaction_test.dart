// Realtime endpoints often authenticate with a query token. What
// RawWebSocketClientImpl writes - its log lines and the cancellation error a
// caller may forward to crash reporting - used to carry the full URL.

import 'dart:io';

import 'package:flutter_starter/core/network/realtime/raw_websocket_client.dart';
import 'package:flutter_starter/core/network/ssl_pinning.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

class _RecordingOutput extends LogOutput {
  final List<String> lines = [];

  @override
  void output(OutputEvent event) => lines.addAll(event.lines);
}

const _noPinning = SslPinning(enabled: false, fingerprints: []);

void main() {
  late _RecordingOutput logs;
  late LogOutput Function() originalOutput;

  setUp(() {
    logs = _RecordingOutput();
    originalOutput = Logger.defaultOutput;
    // The client builds its own Logger(), which takes the package default.
    Logger.defaultOutput = () => logs;
  });

  tearDown(() => Logger.defaultOutput = originalOutput);

  test('a cancelled handshake names the URL without its token', () async {
    // Completes the handshake only after the client has disconnected, which
    // is when connect() reports the cancellation.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await WebSocketTransformer.upgrade(request);
    });
    final client = RawWebSocketClientImpl(sslPinning: _noPinning);

    final connecting = client.connect(
      'ws://127.0.0.1:${server.port}/socket?token=SECRET&room=lobby',
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    client.disconnect();

    Object? thrown;
    try {
      await connecting;
    } on Object catch (e) {
      thrown = e;
    }

    expect(thrown, isNotNull);
    expect('$thrown', isNot(contains('SECRET')));
    expect('$thrown', contains('room=lobby'));
    expect(logs.lines.join('\n'), isNot(contains('SECRET')));
  });

  test('a failed handshake logs no token', () async {
    final client = RawWebSocketClientImpl(sslPinning: _noPinning);

    await expectLater(
      client.connect('ws://127.0.0.1:1/socket?access_token=SECRET'),
      throwsA(anything),
    );

    expect(logs.lines, isNotEmpty);
    expect(logs.lines.join('\n'), isNot(contains('SECRET')));
  });

  test('a URL with no sensitive key is logged in full', () async {
    final client = RawWebSocketClientImpl(sslPinning: _noPinning);

    await expectLater(
      client.connect('ws://127.0.0.1:1/socket?room=lobby'),
      throwsA(anything),
    );

    expect(logs.lines.join('\n'), contains('/socket?room=lobby'));
  });
}
