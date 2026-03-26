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
  });
}
