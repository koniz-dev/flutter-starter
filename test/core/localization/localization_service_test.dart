import 'package:flutter/material.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockStorageService extends Mock implements StorageService {}

void main() {
  group('SupportedLocale', () {
    test('should have all expected locales', () {
      expect(SupportedLocale.values.length, 4);
      expect(SupportedLocale.en.locale, const Locale('en', 'US'));
      expect(SupportedLocale.es.locale, const Locale('es', 'ES'));
      expect(SupportedLocale.ar.locale, const Locale('ar', 'SA'));
      expect(SupportedLocale.vi.locale, const Locale('vi', 'VN'));
    });

    test('should return correct display names', () {
      expect(SupportedLocale.en.displayName, 'English');
      expect(SupportedLocale.es.displayName, 'Español');
      expect(SupportedLocale.ar.displayName, 'العربية');
      expect(SupportedLocale.vi.displayName, 'Tiếng Việt');
    });

    group('fromLanguageCode', () {
      test('should return correct locale for valid language codes', () {
        expect(SupportedLocale.fromLanguageCode('en'), SupportedLocale.en);
        expect(SupportedLocale.fromLanguageCode('es'), SupportedLocale.es);
        expect(SupportedLocale.fromLanguageCode('ar'), SupportedLocale.ar);
        expect(SupportedLocale.fromLanguageCode('vi'), SupportedLocale.vi);
      });

      test('should return null for invalid language code', () {
        expect(SupportedLocale.fromLanguageCode('fr'), isNull);
        expect(SupportedLocale.fromLanguageCode('de'), isNull);
        expect(SupportedLocale.fromLanguageCode('invalid'), isNull);
      });

      test('should return null for null language code', () {
        expect(SupportedLocale.fromLanguageCode(null), isNull);
      });

      test('should be case sensitive', () {
        expect(SupportedLocale.fromLanguageCode('EN'), isNull);
        expect(SupportedLocale.fromLanguageCode('En'), isNull);
      });
    });

    group('fromLocaleString', () {
      test('should return correct locale for valid locale strings', () {
        expect(SupportedLocale.fromLocaleString('en_US'), SupportedLocale.en);
        expect(SupportedLocale.fromLocaleString('es_ES'), SupportedLocale.es);
        expect(SupportedLocale.fromLocaleString('ar_SA'), SupportedLocale.ar);
        expect(SupportedLocale.fromLocaleString('vi_VN'), SupportedLocale.vi);
      });

      test('should return correct locale for language code only', () {
        expect(SupportedLocale.fromLocaleString('en'), SupportedLocale.en);
        expect(SupportedLocale.fromLocaleString('es'), SupportedLocale.es);
      });

      test('should return null for invalid locale string', () {
        expect(SupportedLocale.fromLocaleString('fr_FR'), isNull);
        expect(SupportedLocale.fromLocaleString('invalid'), isNull);
      });

      test('should return null for null locale string', () {
        expect(SupportedLocale.fromLocaleString(null), isNull);
      });

      test('should return null for empty locale string', () {
        expect(SupportedLocale.fromLocaleString(''), isNull);
      });

      test('should handle locale strings with multiple underscores', () {
        expect(
          SupportedLocale.fromLocaleString('en_US_EXTRA'),
          SupportedLocale.en,
        );
      });

      test('should handle locale string with only underscore', () {
        expect(SupportedLocale.fromLocaleString('_'), isNull);
      });
    });
  });

  group('LocalizationService', () {
    late LocalizationService localizationService;
    late MockStorageService mockStorageService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockStorageService = MockStorageService();
      localizationService = LocalizationService(
        storageService: mockStorageService,
      );
    });

    group('defaultLocale', () {
      test('should return English locale as default', () {
        expect(LocalizationService.defaultLocale, const Locale('en', 'US'));
      });
    });

    group('supportedLocales', () {
      test('should return all supported locales', () {
        final locales = LocalizationService.supportedLocales;
        expect(locales.length, 4);
        expect(locales, contains(const Locale('en', 'US')));
        expect(locales, contains(const Locale('es', 'ES')));
        expect(locales, contains(const Locale('ar', 'SA')));
        expect(locales, contains(const Locale('vi', 'VN')));
      });
    });

    group('getCurrentLocale', () {
      test('should return default locale when storage is empty', () async {
        when(
          () => mockStorageService.getString(any()),
        ).thenAnswer((_) async => null);

        final locale = await localizationService.getCurrentLocale();

        expect(locale, LocalizationService.defaultLocale);
        verify(() => mockStorageService.getString(any())).called(1);
      });

      test('should return stored locale when valid', () async {
        when(
          () => mockStorageService.getString(any()),
        ).thenAnswer((_) async => 'es');

        final locale = await localizationService.getCurrentLocale();

        expect(locale, const Locale('es', 'ES'));
        verify(() => mockStorageService.getString(any())).called(1);
      });

      test(
        'should return default locale when stored locale is invalid',
        () async {
          when(
            () => mockStorageService.getString(any()),
          ).thenAnswer((_) async => 'fr');

          final locale = await localizationService.getCurrentLocale();

          expect(locale, LocalizationService.defaultLocale);
        },
      );

      test(
        'should return default locale when storage throws exception',
        () async {
          when(
            () => mockStorageService.getString(any()),
          ).thenThrow(Exception('Storage error'));

          final locale = await localizationService.getCurrentLocale();

          expect(locale, LocalizationService.defaultLocale);
        },
      );

      test('should handle all supported locales', () async {
        final testCases = [
          ('en', const Locale('en', 'US')),
          ('es', const Locale('es', 'ES')),
          ('ar', const Locale('ar', 'SA')),
          ('vi', const Locale('vi', 'VN')),
        ];

        for (final (code, expectedLocale) in testCases) {
          when(
            () => mockStorageService.getString(any()),
          ).thenAnswer((_) async => code);

          final locale = await localizationService.getCurrentLocale();
          expect(locale, expectedLocale);
        }
      });
    });

    group('setCurrentLocale', () {
      test('should save locale to storage successfully', () async {
        when(
          () => mockStorageService.setString(any(), any()),
        ).thenAnswer((_) async => true);

        final result = await localizationService.setCurrentLocale(
          const Locale('es', 'ES'),
        );

        expect(result, isTrue);
        verify(() => mockStorageService.setString(any(), 'es')).called(1);
      });

      test('should return false when storage save fails', () async {
        when(
          () => mockStorageService.setString(any(), any()),
        ).thenAnswer((_) async => false);

        final result = await localizationService.setCurrentLocale(
          const Locale('es', 'ES'),
        );

        expect(result, isFalse);
      });

      test('should return false when storage throws exception', () async {
        when(
          () => mockStorageService.setString(any(), any()),
        ).thenThrow(Exception('Storage error'));

        final result = await localizationService.setCurrentLocale(
          const Locale('es', 'ES'),
        );

        expect(result, isFalse);
      });

      test('should save language code for all supported locales', () async {
        final testCases = [
          const Locale('en', 'US'),
          const Locale('es', 'ES'),
          const Locale('ar', 'SA'),
          const Locale('vi', 'VN'),
        ];

        when(
          () => mockStorageService.setString(any(), any()),
        ).thenAnswer((_) async => true);

        for (final locale in testCases) {
          await localizationService.setCurrentLocale(locale);
          verify(
            () => mockStorageService.setString(any(), locale.languageCode),
          ).called(1);
        }
      });
    });

    group('isRTL', () {
      test('should return true for RTL languages', () {
        expect(LocalizationService.isRTL(const Locale('ar', 'SA')), isTrue);
        expect(LocalizationService.isRTL(const Locale('he', 'IL')), isTrue);
        expect(LocalizationService.isRTL(const Locale('fa', 'IR')), isTrue);
        expect(LocalizationService.isRTL(const Locale('ur', 'PK')), isTrue);
      });

      test('should return false for LTR languages', () {
        expect(LocalizationService.isRTL(const Locale('en', 'US')), isFalse);
        expect(LocalizationService.isRTL(const Locale('es', 'ES')), isFalse);
        expect(LocalizationService.isRTL(const Locale('vi', 'VN')), isFalse);
        expect(LocalizationService.isRTL(const Locale('fr', 'FR')), isFalse);
      });

      test('should check language code only, not country', () {
        expect(LocalizationService.isRTL(const Locale('ar', 'EG')), isTrue);
        expect(LocalizationService.isRTL(const Locale('ar', 'US')), isTrue);
      });
    });

    group('getTextDirection', () {
      test('should return RTL for RTL languages', () {
        expect(
          LocalizationService.getTextDirection(const Locale('ar', 'SA')),
          TextDirection.rtl,
        );
        expect(
          LocalizationService.getTextDirection(const Locale('he', 'IL')),
          TextDirection.rtl,
        );
      });

      test('should return LTR for LTR languages', () {
        expect(
          LocalizationService.getTextDirection(const Locale('en', 'US')),
          TextDirection.ltr,
        );
        expect(
          LocalizationService.getTextDirection(const Locale('es', 'ES')),
          TextDirection.ltr,
        );
        expect(
          LocalizationService.getTextDirection(const Locale('vi', 'VN')),
          TextDirection.ltr,
        );
      });
    });

    group('Edge Cases', () {
      test('should handle getCurrentLocale with empty string', () async {
        when(
          () => mockStorageService.getString(any()),
        ).thenAnswer((_) async => '');

        final locale = await localizationService.getCurrentLocale();

        expect(locale, LocalizationService.defaultLocale);
      });

      test('should handle setCurrentLocale with unsupported locale', () async {
        when(
          () => mockStorageService.setString(any(), any()),
        ).thenAnswer((_) async => true);

        final result = await localizationService.setCurrentLocale(
          const Locale('fr', 'FR'),
        );

        expect(result, isTrue);
        verify(() => mockStorageService.setString(any(), 'fr')).called(1);
      });

      test('should handle multiple locale changes', () async {
        when(
          () => mockStorageService.setString(any(), any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockStorageService.getString(any()),
        ).thenAnswer((_) async => 'vi');

        await localizationService.setCurrentLocale(const Locale('en', 'US'));
        await localizationService.setCurrentLocale(const Locale('es', 'ES'));
        await localizationService.setCurrentLocale(const Locale('ar', 'SA'));

        verify(() => mockStorageService.setString(any(), any())).called(3);
      });

      test(
        'should handle getCurrentLocale with whitespace language code',
        () async {
          when(
            () => mockStorageService.getString(any()),
          ).thenAnswer((_) async => '  ');

          final locale = await localizationService.getCurrentLocale();

          expect(locale, LocalizationService.defaultLocale);
        },
      );

      test(
        'should handle getCurrentLocale with numeric language code',
        () async {
          when(
            () => mockStorageService.getString(any()),
          ).thenAnswer((_) async => '123');

          final locale = await localizationService.getCurrentLocale();

          expect(locale, LocalizationService.defaultLocale);
        },
      );
    });
  });
}
