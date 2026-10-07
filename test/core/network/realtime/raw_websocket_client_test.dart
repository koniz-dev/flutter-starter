import 'dart:async';
import 'dart:io';

import 'package:flutter_starter/core/network/realtime/raw_websocket_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Polls [condition] until it holds, failing the test after [timeout].
Future<void> eventually(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

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
      late String url;
      // Sockets the server accepted, and how many of them are still open.
      late int accepted;
      late int open;

      setUp(() async {
        serverReceived = [];
        accepted = 0;
        open = 0;
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        url = 'ws://${server.address.address}:${server.port}';
        server.transform(WebSocketTransformer()).listen((socket) {
          accepted++;
          open++;
          socket.listen(
            (message) {
              serverReceived.add(message);
              socket.add('echo:$message');
            },
            onDone: () => open--,
          );
        });
      });

      tearDown(() async {
        client.disconnect();
        await server.close(force: true);
      });

      test('connects, sends to the server, and receives on stream', () async {
        final received = client.stream.first;

        await client.connect(url);
        expect(client.isConnected, isTrue);

        client.send('ping');

        expect(
          await received.timeout(const Duration(seconds: 5)),
          'echo:ping',
        );
        expect(serverReceived, ['ping']);
      });

      test(
        'disconnect() before the handshake finishes cancels the attempt and '
        'the server sees the socket closed',
        () async {
          final attempt = client.connect(url);
          client.disconnect();

          await expectLater(
            attempt,
            throwsA(isA<WebSocketChannelException>()),
          );
          expect(client.isConnected, isFalse);

          await eventually(() => accepted == 1 && open == 0);
          // Nothing re-adopts the socket afterwards.
          await Future<void>.delayed(const Duration(milliseconds: 200));
          expect(client.isConnected, isFalse);
          expect(open, 0);
        },
      );

      test(
        'two overlapping connect() calls leave exactly one open socket',
        () async {
          final first = client.connect(url);
          final second = client.connect(url);

          await expectLater(
            first,
            throwsA(isA<WebSocketChannelException>()),
          );
          await second;
          expect(client.isConnected, isTrue);

          await eventually(() => accepted == 2 && open == 1);
          await Future<void>.delayed(const Duration(milliseconds: 200));
          expect(open, 1);
        },
      );

      test(
        'closing the superseded socket does not close the current one',
        () async {
          final first = client.connect(url);
          final second = client.connect(url);
          await expectLater(first, throwsA(anything));
          await second;

          // Wait until the superseded socket is closed end to end.
          await eventually(() => accepted == 2 && open == 1);
          await Future<void>.delayed(const Duration(milliseconds: 200));

          expect(client.isConnected, isTrue);
          final received = client.stream.first;
          client.send('still-alive');
          expect(
            await received.timeout(const Duration(seconds: 5)),
            'echo:still-alive',
          );
          expect(open, 1);
        },
      );
    });

    group('connect against a server that never completes the handshake', () {
      late ServerSocket silent;
      late List<Socket> held;

      setUp(() async {
        held = [];
        // Accept TCP but never answer the HTTP upgrade.
        silent = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0)
          ..listen(held.add);
      });

      tearDown(() async {
        for (final socket in held) {
          socket.destroy();
        }
        await silent.close();
      });

      test(
        'fails with a TimeoutException after connectTimeout, with no '
        'unhandled error',
        () async {
          final timed = RawWebSocketClientImpl(
            connectTimeout: const Duration(milliseconds: 300),
          );
          final zoneErrors = <Object>[];
          final done = Completer<void>();
          Object? connectError;
          bool? connectedRightAfter;
          final stopwatch = Stopwatch()..start();

          Future<void> attempt() async {
            try {
              try {
                await timed.connect(
                  'ws://${silent.address.address}:${silent.port}',
                );
              } on Object catch (e) {
                connectError = e;
              }
              connectedRightAfter = timed.isConnected;
              stopwatch.stop();
              // Let the abandoned handshake fail late once the server drops
              // the socket, and check that failure is not unhandled either.
              for (final socket in held) {
                socket.destroy();
              }
              await Future<void>.delayed(const Duration(milliseconds: 300));
            } finally {
              done.complete();
            }
          }

          runZonedGuarded(
            () => unawaited(attempt()),
            (error, stack) => zoneErrors.add(error),
          );
          await done.future;

          expect(connectError, isA<TimeoutException>());
          expect(connectedRightAfter, isFalse);
          expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
          expect(zoneErrors, isEmpty);
        },
      );
    });
  });
}
