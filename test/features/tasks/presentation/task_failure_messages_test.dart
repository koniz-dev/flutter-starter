// Core maps every ValidationFailure to the generic failureValidation, so a
// task saved without a title read "Some of the information isn't valid"
// instead of taskTitleRequired. The tasks screens show failures through
// taskMessage, which knows the slice's own codes.

import 'package:flutter/widgets.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/localization/failure_localizations.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/task_title_rule.dart';
import 'package:flutter_starter/features/tasks/presentation/task_failure_messages.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in const [Locale('en'), Locale('vi')]) {
    final l10n = lookupAppLocalizations(locale);

    test('$locale: a missing title reads as taskTitleRequired', () {
      const failure = ValidationFailure(
        'Title is required',
        code: taskTitleRequiredCode,
      );
      expect(failure.taskMessage(l10n), l10n.taskTitleRequired);
      expect(failure.localizedMessage(l10n), l10n.failureValidation);
    });

    test('$locale: other failures read as core maps them', () {
      const failures = <Failure>[
        ValidationFailure('Bad input', code: 'SOMETHING_ELSE'),
        ValidationFailure('Bad input'),
        NetworkFailure('offline', code: 'CONNECTION_ERROR'),
      ];
      for (final failure in failures) {
        expect(failure.taskMessage(l10n), failure.localizedMessage(l10n));
      }
    });
  }
}
