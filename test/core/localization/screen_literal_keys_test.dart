// An ARB key for the HomeScreen hint, which shipped hard-coded in English.
// This pins that every locale carries a real translation for the screen to use.
//
// The task detail screen's 'Task not found' needs no key: the
// not-found state renders NotFoundFailure through failureNotFound, so the
// literal only ever reaches Failure.message, never the screen.

import 'package:flutter/widgets.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  test('criterion 2 (en): the key keeps the current English wording', () {
    expect(en.homeAddScreensHint, 'Add screens under lib/features/.');
  });

  for (final locale in const ['es', 'vi', 'ar']) {
    final l10n = lookupAppLocalizations(Locale(locale));
    test('criteria 1-2 ($locale): homeAddScreensHint is translated', () {
      expect(l10n.homeAddScreensHint.trim(), isNotEmpty);
      expect(
        l10n.homeAddScreensHint,
        isNot(en.homeAddScreensHint),
        reason: 'still the English text',
      );
    });
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
