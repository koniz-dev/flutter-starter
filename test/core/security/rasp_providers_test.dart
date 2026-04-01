import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/security/i_rasp_service.dart';
import 'package:flutter_starter/core/security/noop_rasp_service.dart';
import 'package:flutter_starter/core/security/rasp_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRaspService extends Mock implements IRaspService {}

void main() {
  group('raspServiceProvider', () {
    test('returns no-op service by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(raspServiceProvider);

      expect(service, isA<NoOpRaspService>());
      expect(service, isA<IRaspService>());
    });

    test('can be overridden in ProviderContainer', () {
      final mockRaspService = MockRaspService();
      final container = ProviderContainer(
        overrides: [raspServiceProvider.overrideWithValue(mockRaspService)],
      );
      addTearDown(container.dispose);

      final service = container.read(raspServiceProvider);

      expect(service, equals(mockRaspService));
      expect(service, isA<IRaspService>());
    });
  });
}
