import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/security/i_rasp_service.dart';
import 'package:flutter_starter/core/security/rasp_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRaspService extends Mock implements IRaspService {}

void main() {
  group('raspServiceProvider', () {
    test('throws by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => container.read(raspServiceProvider),
        throwsA(anything),
      );
    });

    test('can be overridden in ProviderContainer', () {
      final mockRaspService = MockRaspService();
      final container = ProviderContainer(
        overrides: [
          raspServiceProvider.overrideWithValue(mockRaspService),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(raspServiceProvider);

      expect(service, equals(mockRaspService));
      expect(service, isA<IRaspService>());
    });
  });
}
