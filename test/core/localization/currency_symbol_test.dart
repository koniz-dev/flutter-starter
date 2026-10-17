// formatCurrency with an explicit currency code must use intl's symbol
// (koniz-dev/flutter-starter#327).
//
// A 14-entry hand-written table overrode intl and fell back to the bare ISO
// code, so VND - the currency of the app's own vi locale - printed as
// "150.000 VND" while the same call without a code printed "150.000 ₫".

import 'dart:ui';

import 'package:flutter_starter/core/localization/localized_formatters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  setUpAll(() async => initializeDateFormatting());

  String format(num amount, String locale, String code) =>
      LocalizedFormatters.formatCurrency(
        amount,
        locale: Locale.fromSubtags(
          languageCode: locale.split('_').first,
          countryCode: locale.contains('_') ? locale.split('_').last : null,
        ),
        currencyCode: code,
      );

  test('criterion 1: VND in vi_VN uses ₫, not the ISO code', () {
    final text = format(150000, 'vi_VN', 'VND');
    expect(text, contains('₫'));
    expect(text, isNot(contains('VND')));
  });

  test("criterion 2: KRW in ko and EUR in es use intl's symbol", () {
    expect(format(1000, 'ko', 'KRW'), contains('₩'));
    expect(format(10, 'es', 'EUR'), contains('€'));
  });

  test('the symbol is exactly what intl gives for that locale and code', () {
    for (final (locale, code) in const [
      ('vi_VN', 'VND'),
      ('ko', 'KRW'),
      ('es', 'EUR'),
      ('en_US', 'USD'),
      ('ja', 'JPY'),
      ('ar', 'SAR'),
    ]) {
      final expected = NumberFormat.simpleCurrency(
        locale: locale,
        name: code,
      ).currencySymbol;
      expect(
        format(1, locale, code),
        contains(expected),
        reason: '$code in $locale',
      );
    }
  });

  test('zero-decimal currencies stay without cents', () {
    expect(format(150000, 'vi_VN', 'VND'), isNot(contains(',00')));
    expect(format(1000, 'ja', 'JPY'), isNot(contains('.00')));
  });
}
