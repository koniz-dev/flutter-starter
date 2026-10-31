// formatCurrency without a currency code fell back to the default currency
// of the locale's language, so the app's own ar_SA printed Egyptian pounds
// (`1,234.56 E£`). It now uses the currency of the locale's country.

import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/core/localization/localized_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // intl separates the amount and the symbol with U+00A0; ar opens with
  // U+200F, a right-to-left mark.
  const expected = {
    SupportedLocale.en: r'$1,234.56',
    SupportedLocale.es: '1.234,56 €',
    SupportedLocale.ar: '‏1,234.56 Riyal',
    SupportedLocale.vi: '1.235 ₫',
  };

  test('every supported locale gets its own country currency', () {
    expect(expected.keys.toSet(), SupportedLocale.values.toSet());
    for (final MapEntry(key: locale, value: text) in expected.entries) {
      expect(
        LocalizedFormatters.formatCurrency(1234.56, locale: locale.locale),
        text,
        reason: locale.name,
      );
    }
  });

  test('ar_SA does not print Egyptian pounds', () {
    final text = LocalizedFormatters.formatCurrency(
      1234.56,
      locale: SupportedLocale.ar.locale,
    );
    expect(text, isNot(contains('E£')));
  });

  test('an explicit code still wins', () {
    expect(
      LocalizedFormatters.formatCurrency(
        1234.56,
        locale: SupportedLocale.ar.locale,
        currencyCode: 'USD',
      ),
      '\u200f1,234.56\u00a0\$',
    );
  });
}
