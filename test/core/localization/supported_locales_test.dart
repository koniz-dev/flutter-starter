// Regression tests for koniz-dev/flutter-starter#65, criteria 8, 10 and 12.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupportedLocale.fromLocaleString', () {
    test('accepts the BCP-47 hyphen form reported by browsers', () {
      expect(SupportedLocale.fromLocaleString('en-US'), SupportedLocale.en);
      expect(SupportedLocale.fromLocaleString('vi-VN'), SupportedLocale.vi);
      expect(SupportedLocale.fromLocaleString('ar-SA'), SupportedLocale.ar);
    });

    test('still accepts the underscore form', () {
      expect(SupportedLocale.fromLocaleString('en_US'), SupportedLocale.en);
      expect(SupportedLocale.fromLocaleString('es_ES'), SupportedLocale.es);
    });

    test('returns null for unknown or null input', () {
      expect(SupportedLocale.fromLocaleString('de-DE'), isNull);
      expect(SupportedLocale.fromLocaleString(null), isNull);
    });
  });

  group('supportedLocales single source of truth', () {
    test('LocalizationService derives its list from SupportedLocale', () {
      expect(
        LocalizationService.supportedLocales,
        SupportedLocale.values.map((locale) => locale.locale).toList(),
      );
    });

    test('the enum and the generated AppLocalizations list agree', () {
      final fromEnum = SupportedLocale.values
          .map((l) => l.locale.languageCode)
          .toSet();
      final fromGenerated = AppLocalizations.supportedLocales
          .map((locale) => locale.languageCode)
          .toSet();

      expect(
        fromEnum,
        fromGenerated,
        reason:
            'SupportedLocale and the ARB-generated AppLocalizations have '
            'drifted; add or remove the locale in both places',
      );
    });

    test('every supported locale resolves to real strings', () {
      for (final supported in SupportedLocale.values) {
        final l10n = lookupAppLocalizations(supported.locale);
        expect(l10n.retry, isNotEmpty);
        expect(l10n.noItemsFound, isNotEmpty);
      }
    });
  });

  group('Arabic plurals cover the CLDR categories', () {
    late Map<String, dynamic> arb;

    setUpAll(() {
      arb =
          jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync())
              as Map<String, dynamic>;
    });

    for (final key in ['itemCount', 'minutesAgo']) {
      test('$key declares zero/one/two/few/many/other', () {
        final pattern = arb[key]! as String;
        for (final category in [
          'zero{',
          'one{',
          'two{',
          'few{',
          'many{',
          'other{',
        ]) {
          expect(
            pattern.contains(category),
            isTrue,
            reason: '$key is missing the CLDR "$category" category',
          );
        }
      });
    }

    test('itemCount(2) uses the Arabic dual form', () {
      final ar = lookupAppLocalizations(const Locale('ar'));
      expect(ar.itemCount(2), 'عنصران');
      expect(ar.itemCount(2), isNot(contains('2')));
    });

    test('minutesAgo(2) uses the Arabic dual form', () {
      final ar = lookupAppLocalizations(const Locale('ar'));
      expect(ar.minutesAgo(2), 'منذ دقيقتين');
    });

    test('other Arabic categories still render', () {
      final ar = lookupAppLocalizations(const Locale('ar'));
      expect(ar.itemCount(0), 'لا توجد عناصر');
      expect(ar.itemCount(1), 'عنصر واحد');
      expect(ar.itemCount(3), contains('3'));
      expect(ar.itemCount(11), contains('11'));
    });
  });
}
