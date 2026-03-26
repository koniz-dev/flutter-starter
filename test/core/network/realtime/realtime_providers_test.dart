import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/network/realtime/i_realtime_client.dart';
import 'package:flutter_starter/core/network/realtime/noop_realtime_client.dart';
import 'package:flutter_starter/core/network/realtime/realtime_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRealtimeClient extends Mock implements IRealtimeClient {}

void main() {
  group('realtimeClientProvider', () {
    test('provides a NoOpRealtimeClient by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final client = container.read(realtimeClientProvider);

      expect(client, isA<NoOpRealtimeClient>());
    });

    test('returns the same instance on multiple reads', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final client1 = container.read(realtimeClientProvider);
      final client2 = container.read(realtimeClientProvider);

      expect(identical(client1, client2), isTrue);
    });

    test('can be overridden with a mock implementation', () {
      final mockClient = MockRealtimeClient();
      final container = ProviderContainer(
        overrides: [
          realtimeClientProvider.overrideWithValue(mockClient),
        ],
      );
      addTearDown(container.dispose);

      final client = container.read(realtimeClientProvider);

      expect(client, equals(mockClient));
    });

    test('independent containers have different instances', () {
      final container1 = ProviderContainer();
      final container2 = ProviderContainer();
      addTearDown(container1.dispose);
      addTearDown(container2.dispose);

      final client1 = container1.read(realtimeClientProvider);
      final client2 = container2.read(realtimeClientProvider);

      expect(identical(client1, client2), isFalse);
    });
  });
}
