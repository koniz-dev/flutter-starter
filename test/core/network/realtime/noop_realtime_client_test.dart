import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/network/realtime/noop_realtime_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NoOpRealtimeClient', () {
    late NoOpRealtimeClient client;

    setUp(() {
      client = NoOpRealtimeClient();
    });

    test('isConnected always returns false', () {
      expect(client.isConnected, isFalse);
    });

    test('stream returns a broadcast stream', () {
      expect(client.stream, isA<Stream<dynamic>>());
      expect(client.stream.isBroadcast, isTrue);
    });

    test('connect completes without error', () async {
      await expectLater(client.connect('ws://localhost:8080'), completes);
    });

    test('isConnected remains false after connect', () async {
      await client.connect('ws://localhost:8080');
      expect(client.isConnected, isFalse);
    });

    test('disconnect completes without error', () {
      expect(() => client.disconnect(), returnsNormally);
    });

    test('send completes without error', () {
      expect(
        () => client.send({'type': 'message', 'data': 'hello'}),
        returnsNormally,
      );
    });

    test('send with string data completes without error', () {
      expect(() => client.send('test message'), returnsNormally);
    });

    test('send with null data completes without error', () {
      expect(() => client.send(null), returnsNormally);
    });

    test('connect prints debug message', () async {
      final logs = <String>[];
      debugPrint = (message, {wrapWidth}) {
        if (message != null) logs.add(message);
      };

      await client.connect('ws://example.com');

      expect(
        logs,
        contains(
          'NoOpRealtimeClient: Simulated connection to '
          'ws://example.com',
        ),
      );

      debugPrint = debugPrintSynchronously;
    });

    test('disconnect prints debug message', () {
      final logs = <String>[];
      debugPrint = (message, {wrapWidth}) {
        if (message != null) logs.add(message);
      };

      client.disconnect();

      expect(logs, contains('NoOpRealtimeClient: Simulated disconnection'));

      debugPrint = debugPrintSynchronously;
    });

    test('send prints the payload type, never its content', () {
      final logs = <String>[];
      debugPrint = (message, {wrapWidth}) {
        if (message != null) logs.add(message);
      };

      client.send('hello');

      expect(logs, contains('NoOpRealtimeClient: Simulated send of a String'));
      expect(logs.join('\n'), isNot(contains('hello')));

      debugPrint = debugPrintSynchronously;
    });

    // The default realtimeClientProvider: realtime code written before a
    // real client is wired sends real URLs and payloads through it.
    test('connect prints the URL without its token, and send prints no '
        'payload', () async {
      final logs = <String>[];
      debugPrint = (message, {wrapWidth}) {
        if (message != null) logs.add(message);
      };
      addTearDown(() => debugPrint = debugPrintSynchronously);

      await client.connect('wss://u:PASS-SECRET@h/s?token=SECRET&room=lobby');
      client.send({'auth': 'PAYLOAD-SECRET'});

      final printed = logs.join('\n');
      expect(printed, isNot(contains('SECRET')));
      expect(printed, contains('room=lobby'));
    });

    test('multiple operations in sequence work', () async {
      await client.connect('ws://localhost');
      client
        ..send('hello')
        ..send('world')
        ..disconnect();
      expect(client.isConnected, isFalse);
    });

    test('stream emits no events on send', () async {
      final events = <dynamic>[];
      final sub = client.stream.listen(events.add);

      client.send('test');
      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);
      await sub.cancel();
    });
  });
}
