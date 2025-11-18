import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';

/// Provider for [LocalizationService] instance
///
/// This provider creates a singleton instance of [LocalizationService] that
/// manages application localization and language preferences.
final localizationServiceProvider = Provider<LocalizationService>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return LocalizationService(storageService: storageService);
});

/// Provider for current locale
///
/// This provider watches the current locale from storage and updates
/// when the locale changes.
final currentLocaleProvider = FutureProvider<Locale>((ref) async {
  final localizationService = ref.watch(localizationServiceProvider);
  return localizationService.getCurrentLocale();
});

/// Notifier for managing locale state
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    // Initialize from storage when provider is first created
    ref.listen<AsyncValue<Locale>>(currentLocaleProvider, (previous, next) {
      next.whenData((Locale locale) {
        state = locale;
      });
    });
    return LocalizationService.defaultLocale;
  }

  /// Gets the current locale
  Locale get locale => state;

  /// Sets the current locale
  ///
  /// Updates the app's locale state and persists the preference to storage.
  set locale(Locale locale) {
    state = locale;
  }
}

/// State provider for current locale (synchronous)
///
/// This provider holds the current locale state and can be updated
/// synchronously. It should be initialized from [currentLocaleProvider].
final localeStateProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

/// Provider for text direction based on current locale
final textDirectionProvider = Provider<TextDirection>((ref) {
  final locale = ref.watch(localeStateProvider);
  return LocalizationService.getTextDirection(locale);
});

/// Provider for RTL check based on current locale
final isRTLProvider = Provider<bool>((ref) {
  final locale = ref.watch(localeStateProvider);
  return LocalizationService.isRTL(locale);
});
