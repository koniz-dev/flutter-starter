import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/localization/failure_localizations.dart';
import 'package:flutter_starter/features/tasks/domain/usecases/task_title_rule.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';

/// User-facing text for a failure shown by the tasks screens.
///
/// Core maps every `ValidationFailure` to the generic `failureValidation`,
/// since it cannot know a feature's codes; the tasks slice knows its own, so
/// a missing title reads as `taskTitleRequired` wherever it surfaces.
extension TaskFailureMessages on Failure {
  /// [localizedMessage], with the tasks slice's own validation codes.
  String taskMessage(AppLocalizations l10n) => switch (code) {
    taskTitleRequiredCode => l10n.taskTitleRequired,
    _ => localizedMessage(l10n),
  };
}
