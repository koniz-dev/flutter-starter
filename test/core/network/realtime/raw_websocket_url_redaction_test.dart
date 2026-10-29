// Realtime endpoints often authenticate with a query token. What
// RawWebSocketClientImpl writes - its log lines and the cancellation error a
// caller may forward to crash reporting - used to carry the full URL.

import 'dart:async';
import 'dart:io';

import 'package:flutter_starter/core/network/realtime/raw_websocket_client.dart';
import 'package:flutter_starter/core/network/ssl_pinning.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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

  // A server refusing the upgrade - what an expired token gets - makes
  // dart:io throw an error quoting the full URL. connect() rethrew it.
  test('a refused handshake rethrows an error without the token or the '
      'userinfo password', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      request.response.statusCode = HttpStatus.forbidden;
      unawaited(request.response.close());
    });
    final client = RawWebSocketClientImpl(sslPinning: _noPinning);

    Object? thrown;
    try {
      await client.connect(
        'ws://user:hunter2@127.0.0.1:${server.port}/s?token=SECRET&room=lobby',
      );
    } on Object catch (e) {
      thrown = e;
    }

    expect(thrown, isA<WebSocketChannelException>());
    expect('$thrown', isNot(contains('SECRET')));
    expect('$thrown', isNot(contains('hunter2')));
    // What the caller needs to diagnose it is kept: where, and what failed.
    expect('$thrown', contains('WebSocketException'));
    expect('$thrown', contains('room=lobby'));
    expect((thrown! as WebSocketChannelException).inner, isNull);
    expect(logs.lines.join('\n'), isNot(contains('hunter2')));
  });

  /// Connects to a loopback server that refuses the upgrade with 403 and
  /// returns what connect() threw.
  Future<Object?> refusedConnect(String Function(int port) urlFor) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      request.response.statusCode = HttpStatus.forbidden;
      unawaited(request.response.close());
    });
    final client = RawWebSocketClientImpl(sslPinning: _noPinning);
    try {
      await client.connect(urlFor(server.port));
    } on Object catch (e) {
      return e;
    }
    return null;
  }

  // dart:io quotes the URL in '...'; scrubbing its text stopped at the first
  // apostrophe inside the URL and left the rest raw.
  test(
    'an apostrophe in an earlier query value does not expose the token',
    () async {
      final thrown = await refusedConnect(
        (port) => "ws://127.0.0.1:$port/s?name=O'Brien&token=SECRET",
      );

      expect(thrown, isA<WebSocketChannelException>());
      expect('$thrown', isNot(contains('SECRET')));
    },
  );

  // Uri normalises userinfo, so looking it up through Uri missed the raw
  // text and the password stayed in the logs and both errors.
  for (final password in ['SECRET%2fx', 'SECRET%41', 'SECRETé', 'SECRET x']) {
    test(
      'userinfo "u:$password" is redacted from the error and the logs',
      () async {
        final thrown = await refusedConnect(
          (port) => 'ws://u:$password@127.0.0.1:$port/s',
        );

        expect(thrown, isNotNull);
        expect('$thrown', isNot(contains('SECRET')));
        expect(logs.lines.join('\n'), isNot(contains('SECRET')));
      },
    );
  }

  test(
    'an unparsable URL throws a FormatException without the token',
    () async {
      final client = RawWebSocketClientImpl(sslPinning: _noPinning);

      Object? thrown;
      try {
        await client.connect('wss://u:PASS@host:443x/socket?token=SECRET');
      } on Object catch (e) {
        thrown = e;
      }

      expect(thrown, isA<FormatException>());
      expect('$thrown', isNot(contains('SECRET')));
      expect('$thrown', isNot(contains('PASS')));
      expect(logs.lines.join('\n'), isNot(contains('PASS')));
    },
  );
}
