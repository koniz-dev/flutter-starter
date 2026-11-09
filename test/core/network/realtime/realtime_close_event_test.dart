import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/network/realtime/i_realtime_client.dart';
import 'package:flutter_starter/core/network/realtime/raw_websocket_client.dart';
import 'package:flutter_starter/core/network/realtime/realtime_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final code in [1000, 1001]) {
    test(
      'server close $code is observable by an existing subscriber',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final accepted = Completer<WebSocket>();
        server.transform(WebSocketTransformer()).listen(accepted.complete);
        final client = RawWebSocketClientImpl();
        final hello = Completer<void>();
        final closed = Completer<Object?>();
        final subscription = client.stream.listen(
          (dynamic message) {
            if (message == 'hello' && !hello.isCompleted) hello.complete();
          },
          onError: (Object error) {
            if (!closed.isCompleted) closed.complete(error);
          },
        );
        try {
          await client.connect('ws://127.0.0.1:${server.port}');
          final peer = await accepted.future;
          peer.add('hello');
          await hello.future.timeout(const Duration(seconds: 5));
          await peer.close(code);
          final event = await closed.future.timeout(
            const Duration(seconds: 5),
            onTimeout: () => null,
          );
          expect(event, isA<RealtimeConnectionClosed>());
          expect((event! as RealtimeConnectionClosed).code, code);
          expect(client.isConnected, isFalse);
        } finally {
          client.disconnect();
          await subscription.cancel();
          await server.close(force: true);
        }
      },
    );
  }

  test('provider disposal disconnects its factory-owned socket', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final accepted = Completer<WebSocket>();
    final peerClosed = Completer<void>();
    server.transform(WebSocketTransformer()).listen((socket) {
      accepted.complete(socket);
      socket.listen((dynamic _) {}, onDone: peerClosed.complete);
    });
    final errors = <Object>[];
    final client = RawWebSocketClientImpl();
    final container = ProviderContainer(
      overrides: [
        realtimeClientFactoryProvider.overrideWithValue(() => client),
      ],
    );
    var disposed = false;
    final owned = container.read(realtimeClientProvider);
    final subscription = owned.stream.listen(
      (dynamic _) {},
      onError: errors.add,
    );
    try {
      await owned.connect('ws://127.0.0.1:${server.port}');
      await accepted.future;
      expect(owned.isConnected, isTrue);
      container.dispose();
      disposed = true;
      expect(owned.isConnected, isFalse);
      await peerClosed.future.timeout(const Duration(seconds: 5));
      await pumpEventQueue();
      expect(
        errors,
        isEmpty,
        reason: 'intentional disposal is not remote close',
      );
    } finally {
      if (!disposed) container.dispose();
      client.disconnect();
      await subscription.cancel();
      await server.close(force: true);
    }
  });
}
