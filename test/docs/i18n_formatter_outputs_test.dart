// The internationalization guide showed formatter outputs intl never prints
// for the app's locales: Arabic-Indic digits for ar_SA, euros and riyals for
// an amount formatted with `currencyCode: 'USD'`, `1.2M` for en_US. Every
// `// <locale>: "<output>"` comment there is now what LocalizedFormatters
// prints for that SupportedLocale.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/core/localization/localized_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

/// [text] without the direction marks intl adds and with non-breaking
/// spaces made plain, as the guide shows it.
String _visible(String text) => text
    .replaceAll(RegExp('[\u200e\u200f\u061c]'), '')
    .replaceAll(RegExp('[\u00a0\u202f]'), ' ');

/// For each formatter the guide shows, what its snippet prints for a locale.
final Map<String, String Function(Locale locale)> _snippets = {
  'formatNumber': (locale) => LocalizedFormatters.formatNumber(
    1234.56,
    locale: locale,
    decimalDigits: 2,
  ),
  'formatCurrency': (locale) => LocalizedFormatters.formatCurrency(
    1234.56,
    locale: locale,
    currencyCode: 'USD',
  ),
  'formatCompactNumber': (locale) =>
      LocalizedFormatters.formatCompactNumber(1234567, locale: locale),
};

void main() {
  final guide = File(
    'docs/guides/features/internationalization-guide.md',
  ).readAsStringSync();
  final blocks = RegExp(
    r'```dart\n(.*?)```',
    dotAll: true,
  ).allMatches(guide).map((m) => m.group(1)!).toList();
  final output = RegExp(r'^// (\w+): "(.*)"$', multiLine: true);

  for (final MapEntry(key: formatter, value: format) in _snippets.entries) {
    test('the $formatter outputs are what it prints for each locale', () {
      final block = blocks.singleWhere(
        (b) =>
            b.contains('LocalizedFormatters.$formatter(') && output.hasMatch(b),
      );
      final documented = {
        for (final m in output.allMatches(block)) m.group(1)!: m.group(2)!,
      };

      expect(
        documented.keys.toSet(),
        {for (final l in SupportedLocale.values) l.locale.toString()},
      );
      for (final supported in SupportedLocale.values) {
        final name = supported.locale.toString();
        expect(
          documented[name],
          _visible(format(supported.locale)),
          reason: '$formatter, $name',
        );
      }
    });
  }

  test('no output comment is left in the old language-name form', () {
    expect(
      guide,
      isNot(
        contains(RegExp('^// (English|Spanish|Arabic):', multiLine: true)),
      ),
    );
  });
}
