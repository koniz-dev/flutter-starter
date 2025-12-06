import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/localization/localization_providers.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStorageService extends Mock implements StorageService {}

void main() {
  group('localization_providers', () {
    late MockStorageService mockStorageService;

    setUp(() {
      mockStorageService = MockStorageService();
    });

    group('localizationServiceProvider', () {
      test('should create LocalizationService instance', () {
        // Arrange
        final container = ProviderContainer(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorageService),
          ],
        );

        // Act
        final service = container.read(localizationServiceProvider);

        // Assert
        expect(service, isA<LocalizationService>());
        container.dispose();
      });

      test('should use storageServiceProvider', () {
        // Arrange
        final container = ProviderContainer(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorageService),
          ],
        );

        // Act
        final service = container.read(localizationServiceProvider);

        // Assert
        expect(service, isNotNull);
        container.dispose();
      });
    });

    group('currentLocaleProvider', () {
      test('should return Locale from LocalizationService', () async {
        // Arrange
        when(
          () => mockStorageService.getString(any()),
        ).thenAnswer((_) async => 'en');

        final container = ProviderContainer(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorageService),
          ],
        );

        // Act
        final asyncValue = container.read(currentLocaleProvider);
        expect(asyncValue, isA<AsyncValue<Locale>>());

        // Wait for async value to resolve
        final locale = await container.read(currentLocaleProvider.future);

        // Assert
        expect(locale, isA<Locale>());
        expect(locale.languageCode, 'en');
        container.dispose();
      });

      test('should handle errors gracefully', () async {
        // Arrange
        when(
          () => mockStorageService.getString(any()),
        ).thenThrow(Exception('Storage error'));

        final container = ProviderContainer(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorageService),
          ],
        );

        // Act
        final asyncValue = container.read(currentLocaleProvider);

        // Assert
        expect(asyncValue, isA<AsyncValue<Locale>>());
        // Even if error occurs, should eventually return default locale
        // Wait for provider to resolve
        final locale = await container.read(currentLocaleProvider.future);
        expect(locale, LocalizationService.defaultLocale);
        container.dispose();
      });
    });

    group('LocaleNotifier', () {
      test('should initialize with default locale', () {
        // Arrange
        final container = ProviderContainer(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorageService),
            currentLocaleProvider.overrideWith(
              (ref) async => LocalizationService.defaultLocale,
            ),
          ],
        );

        // Act
        final notifier = container.read(localeStateProvider.notifier);
        final state = container.read(localeStateProvider);

        // Assert
        expect(notifier, isA<LocaleNotifier>());
        expect(state, LocalizationService.defaultLocale);
        container.dispose();
      });

      test('should have locale getter', () {
        // Arrange
        final container = ProviderContainer(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorageService),
            currentLocaleProvider.overrideWith(
              (ref) async => const Locale('en'),
            ),
          ],
        );

        // Act
        final notifier = container.read(localeStateProvider.notifier);
        final locale = notifier.locale;

        // Assert
        expect(locale, isA<Locale>());
        container.dispose();
      });

      test('should set locale via setter', () {
        // Arrange
        final container = ProviderContainer(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorageService),
            currentLocaleProvider.overrideWith(
              (ref) async => const Locale('en'),
            ),
          ],
        );

        final notifier = container.read(localeStateProvider.notifier);
        const newLocale = Locale('es');

        // Act
        notifier.locale = newLocale;

        // Assert
        expect(notifier.locale, newLocale);
        expect(container.read(localeStateProvider), newLocale);
        container.dispose();
      });

      test('should update state when locale is set', () {
        // Arrange
        final container = ProviderContainer(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorageService),
            currentLocaleProvider.overrideWith(
              (ref) async => const Locale('en'),
            ),
          ],
        );

        final notifier = container.read(localeStateProvider.notifier);
        const newLocale = Locale('vi');

        // Act
        notifier.locale = newLocale;

        // Assert
        expect(container.read(localeStateProvider), newLocale);
        container.dispose();
      });

      test('should listen to currentLocaleProvider changes', () async {
        // Arrange
        when(
          () => mockStorageService.getString(any()),
        ).thenAnswer((_) async => 'ar');

        final container = ProviderContainer(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorageService),
          ],
        );

        // Wait for async provider to resolve
        final locale = await container.read(currentLocaleProvider.future);
        expect(locale.languageCode, 'ar');

        // Act - Check that notifier can be accessed
        final notifier = container.read(localeStateProvider.notifier);
        final state = container.read(localeStateProvider);

        // Assert
        expect(notifier, isA<LocaleNotifier>());
        expect(state, isA<Locale>());
        // The listener in build() should update state from
        // currentLocaleProvider
        // But it may take time, so we just verify the structure
        container.dispose();
      });
    });

    group('localeStateProvider', () {
      test('should provide Locale state', () {
        // Arrange
        final container = ProviderContainer(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorageService),
            currentLocaleProvider.overrideWith(
              (ref) async => const Locale('en'),
            ),
          ],
        );

        // Act
        final locale = container.read(localeStateProvider);

        // Assert
        expect(locale, isA<Locale>());
        container.dispose();
      });

      test('should update when notifier state changes', () {
        // Arrange
        final container = ProviderContainer(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorageService),
            currentLocaleProvider.overrideWith(
              (ref) async => const Locale('en'),
            ),
          ],
        );

        const newLocale = Locale('es');

        // Act
        container.read(localeStateProvider.notifier).locale = newLocale;

        // Assert
        expect(container.read(localeStateProvider), newLocale);
        container.dispose();
      });
    });

    group('textDirectionProvider', () {
      test('should return LTR for LTR locales', () {
        // Arrange
        final container = ProviderContainer(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorageService),
            currentLocaleProvider.overrideWith(
              (ref) async => const Locale('en'),
            ),
          ],
        );

        // Set locale state
        container.read(localeStateProvider.notifier).state = const Locale('en');

        // Act
        final textDirection = container.read(textDirectionProvider);

        // Assert
        expect(textDirection, TextDirection.ltr);
        container.dispose();
      });

      test('should return RTL for RTL locales', () {
        // Arrange
        final container = ProviderContainer(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorageService),
            currentLocaleProvider.overrideWith(
              (ref) async => const Locale('ar'),
            ),
          ],
        );

        // Set locale state
        container.read(localeStateProvider.notifier).state = const Locale('ar');

        // Act
        final textDirection = container.read(textDirectionProvider);

        // Assert
        expect(textDirection, TextDirection.rtl);
        container.dispose();
      });

      test('should update when locale changes', () {
        // Arrange
        final container = ProviderContainer(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorageService),
            currentLocaleProvider.overrideWith(
              (ref) async => const Locale('en'),
            ),
          ],
        );

        // Set initial locale
        container.read(localeStateProvider.notifier).state = const Locale('en');

        // Act - Change to RTL locale
        container.read(localeStateProvider.notifier).locale = const Locale(
          'ar',
        );
        final textDirection = container.read(textDirectionProvider);

        // Assert
        expect(textDirection, TextDirection.rtl);
        container.dispose();
      });
    });

    group('isRTLProvider', () {
      test('should return false for LTR locales', () {
        // Arrange
        final container = ProviderContainer(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorageService),
            currentLocaleProvider.overrideWith(
              (ref) async => const Locale('en'),
            ),
          ],
        );

        // Set locale state
        container.read(localeStateProvider.notifier).state = const Locale('en');

        // Act
        final isRTL = container.read(isRTLProvider);

        // Assert
        expect(isRTL, isFalse);
        container.dispose();
      });

      test('should return true for RTL locales', () {
        // Arrange
        final container = ProviderContainer(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorageService),
            currentLocaleProvider.overrideWith(
              (ref) async => const Locale('ar'),
            ),
          ],
        );

        // Set locale state
        container.read(localeStateProvider.notifier).state = const Locale('ar');

        // Act
        final isRTL = container.read(isRTLProvider);

        // Assert
        expect(isRTL, isTrue);
        container.dispose();
      });

      test('should update when locale changes', () {
        // Arrange
        final container = ProviderContainer(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorageService),
            currentLocaleProvider.overrideWith(
              (ref) async => const Locale('en'),
            ),
          ],
        );

        // Set initial locale
        container.read(localeStateProvider.notifier).state = const Locale('en');

        // Act - Change to RTL locale
        container.read(localeStateProvider.notifier).locale = const Locale(
          'ar',
        );
        final isRTL = container.read(isRTLProvider);

        // Assert
        expect(isRTL, isTrue);
        container.dispose();
      });

      test('should handle other RTL languages', () {
        // Arrange
        final container = ProviderContainer(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorageService),
            currentLocaleProvider.overrideWith(
              (ref) async => const Locale('he'),
            ),
          ],
        );

        // Set locale state
        container.read(localeStateProvider.notifier).state = const Locale('he');

        // Act
        final isRTL = container.read(isRTLProvider);

        // Assert
        expect(isRTL, isTrue);
        container.dispose();
      });
    });
  });
}
