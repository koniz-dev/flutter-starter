import 'package:flutter/material.dart';
import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';

/// Supported locales in the application
enum SupportedLocale {
  /// English (United States)
  en(Locale('en', 'US'), 'English'),

  /// Spanish (Spain)
  es(Locale('es', 'ES'), 'Español'),

  /// Arabic (Saudi Arabia)
  ar(Locale('ar', 'SA'), 'العربية'),

  /// Vietnamese (Vietnam)
  vi(Locale('vi', 'VN'), 'Tiếng Việt');

  /// Creates a [SupportedLocale] with the given [locale] and [displayName]
  const SupportedLocale(this.locale, this.displayName);

  /// The locale object
  final Locale locale;

  /// Display name of the locale
  final String displayName;

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

  /// Get locale from locale string (e.g., 'en_US', 'es_ES')
  static SupportedLocale? fromLocaleString(String? localeString) {
    if (localeString == null) return null;
    final parts = localeString.split('_');
    if (parts.isEmpty) return null;
    return fromLanguageCode(parts[0]);
  }
}

/// Service for managing application localization
class LocalizationService {
  /// Creates a [LocalizationService] with the given [storageService]
  LocalizationService({
    required StorageService storageService,
  }) : _storageService = storageService;

  final StorageService _storageService;

  /// Storage key for language preference
  static const String _languageKey = AppConstants.languageKey;

  /// Default locale
  static Locale get defaultLocale => SupportedLocale.en.locale;

  /// List of supported locales
  static List<Locale> get supportedLocales => [
    SupportedLocale.en.locale,
    SupportedLocale.es.locale,
    SupportedLocale.ar.locale,
    SupportedLocale.vi.locale,
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
