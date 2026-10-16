import 'package:flutter_starter/core/errors/failures.dart';

/// Failure code for a task saved with a blank title.
const taskTitleRequiredCode = 'TASK_TITLE_REQUIRED';

/// Returns a [ValidationFailure] when [title] is empty or only whitespace,
/// otherwise `null`.
///
/// The domain rule behind the screens' title validators, so a caller that
/// skips the form cannot store a nameless task either.
ValidationFailure? validateTaskTitle(String title) {
  if (title.trim().isNotEmpty) return null;
  return const ValidationFailure(
    'Task title is required',
    code: taskTitleRequiredCode,
  );
}
