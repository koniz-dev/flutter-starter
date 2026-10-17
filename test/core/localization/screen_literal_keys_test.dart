// ARB keys for two strings that shipped screens hard-coded in English
// (koniz-dev/flutter-starter#352): the HomeScreen hint and the task detail
// screen's not-found message. #513 and #514 switch the screens over; this
// pins that every locale carries a real translation for them to switch to.

import 'package:flutter/widgets.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final keys = <String, String Function(AppLocalizations)>{
    'homeAddScreensHint': (l10n) => l10n.homeAddScreensHint,
    'taskNotFound': (l10n) => l10n.taskNotFound,
  };

  test('criterion 2 (en): both keys keep the current English wording', () {
    expect(en.homeAddScreensHint, 'Add screens under lib/features/.');
    expect(en.taskNotFound, 'Task not found');
  });

  for (final locale in const ['es', 'vi', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(locale));
    for (final MapEntry(key: name, value: read) in keys.entries) {
      test('criteria 1-2 ($locale): $name is translated', () {
        expect(read(l10n).trim(), isNotEmpty);
        expect(read(l10n), isNot(read(en)), reason: 'still the English text');
      });
    }
  }

  test('the hint keeps the path untranslated in every locale', () {
    for (final locale in const ['en', 'es', 'vi', 'ar']) {
      expect(
        lookupAppLocalizations(Locale(locale)).homeAddScreensHint,
        contains('lib/features/'),
        reason: locale,
      );
    }
  });
}
