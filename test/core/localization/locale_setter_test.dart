// LocaleNotifier.locale's setter is in-memory only.
// Its doc used to say it "persists the
// preference to storage"; it never did. Persisting is
// LocalizationService.setCurrentLocale's job.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/localization/localization_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/in_memory_stores.dart';

void main() {
  late InMemoryStorage storage;
  late ProviderContainer container;

  setUp(() {
    storage = InMemoryStorage();
    container = ProviderContainer(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
  });

  test('criterion 1: the setter changes the locale and writes nothing', () {
    container.read(localeStateProvider.notifier).locale = const Locale('vi');

    expect(container.read(localeStateProvider), const Locale('vi'));
    expect(storage.values, isEmpty, reason: 'the setter does not persist');
  });

  test('criterion 2: persisting is setCurrentLocale, and startup reads it '
      'back', () async {
    final service = container.read(localizationServiceProvider);
    expect(await service.setCurrentLocale(const Locale('es')), isTrue);
    expect(storage.values, isNotEmpty);

    final next = ProviderContainer(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(next.dispose);
    final restored = await next.read(currentLocaleProvider.future);
    expect(restored.languageCode, 'es');
  });
}
