import 'dart:async';
import 'dart:io';

import 'package:flutter_starter/core/network/realtime/raw_websocket_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RawWebSocketClientImpl', () {
    late RawWebSocketClientImpl client;

    setUp(() {
      client = RawWebSocketClientImpl();
    });

    test('isConnected is false initially', () {
      expect(client.isConnected, isFalse);
    });

    test('stream is a broadcast stream', () {
      expect(client.stream.isBroadcast, isTrue);
    });

    test('disconnect closes channel and sets isConnected to false', () async {
      // Since we can't easily mock the static connect method
      // without extra dependency injection, we assume it's starting null.
      client.disconnect();
      expect(client.isConnected, isFalse);
    });

    test('send does nothing if not connected', () {
      // Should not throw
      expect(() => client.send('test'), returnsNormally);
    });

    group('connect against a refused port', () {
      late String url;

      setUp(() async {
        // Reserve a free port, then release it so nothing listens there.
        final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        url = 'ws://${socket.address.address}:${socket.port}';
        await socket.close();
      });

      test(
        'completes with an error, isConnected is false on the next line, '
        'and no error escapes the zone',
        () async {
          final zoneErrors = <Object>[];
          final streamEvents = <Object?>[];
          final done = Completer<void>();
          Object? connectError;
          bool? connectedRightAfter;

          Future<void> attempt() async {
            try {
              final sub = client.stream.listen(
                streamEvents.add,
                onError: streamEvents.add,
              );
              try {
                await client.connect(url);
              } on Object catch (e) {
                connectError = e;
              }
              connectedRightAfter = client.isConnected;
              // Give any stray async error from the failed attempt time to
              // surface in this zone before we count.
              await Future<void>.delayed(const Duration(milliseconds: 300));
              await sub.cancel();
            } finally {
              done.complete();
            }
          }

          runZonedGuarded(
            () => unawaited(attempt()),
            (error, stack) => zoneErrors.add(error),
          );
          await done.future;

          expect(connectError, isNotNull);
          expect(connectedRightAfter, isFalse);
          expect(client.isConnected, isFalse);
          expect(streamEvents, isEmpty);
          expect(zoneErrors, isEmpty);
        },
      );

      test('send after a failed connect is a no-op', () async {
        await expectLater(client.connect(url), throwsA(anything));
        expect(client.isConnected, isFalse);
        expect(() => client.send('dropped'), returnsNormally);
      });
    });

    group('connect against an in-process server', () {
      late HttpServer server;
      late List<Object?> serverReceived;

      setUp(() async {
        serverReceived = [];
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.transform(WebSocketTransformer()).listen((socket) {
          socket.listen((message) {
            serverReceived.add(message);
            socket.add('echo:$message');
          });
        });
      });

      tearDown(() async {
        client.disconnect();
        await server.close(force: true);
      });

      test('connects, sends to the server, and receives on stream', () async {
        final received = client.stream.first;

        await client.connect('ws://${server.address.address}:${server.port}');
        expect(client.isConnected, isTrue);

        client.send('ping');

        expect(
          await received.timeout(const Duration(seconds: 5)),
          'echo:ping',
        );
        expect(serverReceived, ['ping']);
      });
    });
  });
}
