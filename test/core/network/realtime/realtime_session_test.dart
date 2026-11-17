// The factory-owned realtime client lived as long as the app, so user A's
// authenticated socket stayed open through logout and the next user's
// sign-in, and the next user received A's messages. It now ends with the
// session.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/network/realtime/i_realtime_client.dart';
import 'package:flutter_starter/core/network/realtime/realtime_providers.dart';
import 'package:flutter_starter/core/session/session_providers.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingClient implements IRealtimeClient {
  int disconnects = 0;
  String? url;

  @override
  bool get isConnected => url != null;

  @override
  Stream<dynamic> get stream => const Stream<dynamic>.empty();

  @override
  Future<void> connect(String url) async => this.url = url;

  @override
  void disconnect() {
    disconnects++;
    url = null;
  }

  @override
  void send(dynamic data) {}
}

void main() {
  late List<_RecordingClient> created;
  late ProviderContainer container;

  setUp(() {
    created = [];
    container = ProviderContainer(
      overrides: [
        realtimeClientFactoryProvider.overrideWithValue(() {
          final client = _RecordingClient();
          created.add(client);
          return client;
        }),
      ],
    );
    addTearDown(container.dispose);
  });

  test(
    'a session change disconnects the client, even with no listener',
    () async {
      final first = container.read(realtimeClientProvider);
      await first.connect('wss://h/socket?token=userA');

      // What logout, a forced logout and every sign-in do.
      container.read(sessionGenerationProvider).invalidate();

      expect(created.single.disconnects, 1);
      expect(first.isConnected, isFalse);
    },
  );

  test('the next read after a session change is a fresh client', () async {
    final sub = container.listen(realtimeClientProvider, (_, _) {});
    addTearDown(sub.close);
    final first = sub.read();
    await first.connect('wss://h/socket?token=userA');

    container.read(sessionGenerationProvider).invalidate();
    final second = container.read(realtimeClientProvider);

    expect(identical(first, second), isFalse);
    expect(second.isConnected, isFalse);
    expect(created, hasLength(2));
  });

  test('without a session change the client is kept', () {
    final first = container.read(realtimeClientProvider);
    expect(identical(container.read(realtimeClientProvider), first), isTrue);
    expect(created, hasLength(1));
  });

  test('a direct override of the client is left to its owner', () {
    final owned = _RecordingClient();
    final overridden = ProviderContainer(
      overrides: [realtimeClientProvider.overrideWithValue(owned)],
    );
    addTearDown(overridden.dispose);

    expect(overridden.read(realtimeClientProvider), same(owned));
    overridden.read(sessionGenerationProvider).invalidate();
    expect(overridden.read(realtimeClientProvider), same(owned));
    expect(owned.disconnects, 0);
  });
}
