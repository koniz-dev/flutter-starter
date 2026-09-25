import 'package:flutter/material.dart';
import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';

/// Supported locales in the application
///
/// This enum is the **single source of truth** for which locales the app
/// offers: [LocalizationService.supportedLocales] is derived from it rather
/// than maintained separately. It must stay in step with the generated
/// `AppLocalizations.supportedLocales` (which follows the ARB files in
/// `lib/l10n/`); `test/core/localization/supported_locales_test.dart` fails if
/// the two ever drift.
///
/// [displayName] and [regionDisplayName] are endonyms - deliberately written
/// in the language they name, as a language picker should be, so they are not
/// translated through the ARBs.
enum SupportedLocale {
  /// English (United States)
  en(Locale('en', 'US'), 'English', 'English (United States)'),

  /// Spanish (Spain)
  es(Locale('es', 'ES'), 'Español', 'Español (España)'),

  /// Arabic (Saudi Arabia)
  ar(Locale('ar', 'SA'), 'العربية', 'العربية (السعودية)'),

  /// Vietnamese (Vietnam)
  vi(Locale('vi', 'VN'), 'Tiếng Việt', 'Tiếng Việt (Việt Nam)');

  /// Creates a [SupportedLocale] with the given [locale], [displayName] and
  /// [regionDisplayName]
  const SupportedLocale(this.locale, this.displayName, this.regionDisplayName);

  /// The locale object
  final Locale locale;

  /// Display name of the locale, in that locale's own language
  final String displayName;

  /// Display name including the region, in that locale's own language
  final String regionDisplayName;

  /// Get locale from language code
  static SupportedLocale? fromLanguageCode(String? languageCode) {
    if (languageCode == null) return null;
    for (final supportedLocale in SupportedLocale.values) {
      if (supportedLocale.locale.languageCode == languageCode) {
        return supportedLocale;
      }
    }
    return null;
  }

  /// Get locale from locale string
  ///
  /// Accepts both the Dart/ICU underscore form (`en_US`) and the BCP-47 hyphen
  /// form (`en-US`) that a browser's `navigator.language` reports.
  static SupportedLocale? fromLocaleString(String? localeString) {
    if (localeString == null) return null;
    final parts = localeString.split(RegExp('[_-]'));
    if (parts.isEmpty) return null;
    return fromLanguageCode(parts[0]);
  }

  /// The locale used when nothing else resolves
  static SupportedLocale get fallback => SupportedLocale.en;
}

/// Service for managing application localization
class LocalizationService {
  /// Creates a [LocalizationService] with the given [storageService]
  LocalizationService({required StorageService storageService})
    : _storageService = storageService;

  final StorageService _storageService;

  /// Storage key for language preference
  static const String _languageKey = AppConstants.languageKey;

  /// Default locale
  static Locale get defaultLocale => SupportedLocale.fallback.locale;

  /// List of supported locales
  ///
  /// Derived from [SupportedLocale] so there is one list to maintain, not two.
  static List<Locale> get supportedLocales => [
    for (final supportedLocale in SupportedLocale.values)
      supportedLocale.locale,
  ];

  /// Get current locale from storage or return default
  Future<Locale> getCurrentLocale() async {
    try {
      final languageCode = await _storageService.getString(_languageKey);
      if (languageCode == null) {
        return defaultLocale;
      }

      final supportedLocale = SupportedLocale.fromLanguageCode(languageCode);
      return supportedLocale?.locale ?? defaultLocale;
    } on Exception {
      // If there's an error, return default locale
      return defaultLocale;
    }
  }

  /// Set current locale and save to storage
  Future<bool> setCurrentLocale(Locale locale) async {
    try {
      final success = await _storageService.setString(
        _languageKey,
        locale.languageCode,
      );
      return success;
    } on Exception {
      return false;
    }
  }

  /// Check if locale is RTL (Right-to-Left)
  static bool isRTL(Locale locale) {
    return locale.languageCode == 'ar' ||
        locale.languageCode == 'he' ||
        locale.languageCode == 'fa' ||
        locale.languageCode == 'ur';
  }

  /// Get text direction for locale
  static TextDirection getTextDirection(Locale locale) {
    return isRTL(locale) ? TextDirection.rtl : TextDirection.ltr;
  }
}
