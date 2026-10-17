// Rejected credentials need their own message
// (koniz-dev/flutter-starter#479, split from #445).
//
// Since #309 a 401 on login is an AuthFailure, and every AuthFailure rendered
// as failureAuth - "you're not signed in, or your session has ended" - which
// is wrong for a mistyped password. A failure tagged
// FailureCodes.invalidCredentials renders failureInvalidCredentials instead.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/localization/failure_localizations.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tagged = AuthFailure('x', code: FailureCodes.invalidCredentials);

  for (final locale in const ['en', 'vi']) {
    final l10n = lookupAppLocalizations(Locale(locale));

    test('criterion 3 ($locale): a tagged AuthFailure renders '
        'failureInvalidCredentials', () {
      expect(tagged.localizedMessage(l10n), l10n.failureInvalidCredentials);
      expect(l10n.failureInvalidCredentials, isNot(l10n.failureAuth));
    });

    test('criterion 3 ($locale): a plain AuthFailure still renders '
        'failureAuth', () {
      expect(const AuthFailure('x').localizedMessage(l10n), l10n.failureAuth);
    });
  }

  test('criterion 2: the code wins whatever the failure type', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    for (final failure in const <Failure>[
      ServerFailure('x', code: FailureCodes.invalidCredentials),
      ValidationFailure('x', code: FailureCodes.invalidCredentials),
      UnknownFailure('x', code: FailureCodes.invalidCredentials),
    ]) {
      expect(failure.localizedMessage(l10n), l10n.failureInvalidCredentials);
    }
  });

  test('criterion 1: every ARB file carries the key translated, and the '
      'template describes it', () {
    for (final locale in const ['en', 'vi', 'es', 'ar']) {
      final arb =
          jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
              as Map<String, dynamic>;
      expect(
        arb['failureInvalidCredentials'],
        isA<String>().having((s) => s.trim(), 'trimmed', isNotEmpty),
        reason: 'app_$locale.arb',
      );
    }
    final en =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    expect(
      (en['@failureInvalidCredentials'] as Map)['description'],
      isNotEmpty,
    );
    for (final locale in const ['es', 'ar', 'vi']) {
      expect(
        lookupAppLocalizations(Locale(locale)).failureInvalidCredentials,
        isNot(
          lookupAppLocalizations(const Locale('en')).failureInvalidCredentials,
        ),
        reason: '$locale must be translated, not the English text',
      );
    }
  });
}
