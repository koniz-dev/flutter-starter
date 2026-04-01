import 'package:flutter/foundation.dart';

/// Stable [ValueKey]s for integration / E2E tests (e.g. Patrol).
///
/// Use with Patrol: `await $(#e2e_login_submit).tap();`
abstract final class UiKeys {
  UiKeys._();

  /// Primary action on the login screen.
  static const loginSubmit = ValueKey<String>('e2e_login_submit');

  /// Primary action on the register screen.
  static const registerSubmit = ValueKey<String>('e2e_register_submit');

  /// Home body after authentication (works for full and stripped home UIs).
  static const homeContent = ValueKey<String>('e2e_home_content');

  /// Navigates from home to the tasks list (sample app entry point).
  static const openTasks = ValueKey<String>('e2e_open_tasks');

  /// Tasks list FAB to add a task.
  static const tasksFab = ValueKey<String>('e2e_tasks_fab');

  /// Confirms create-task dialog (label is l10n-dependent; key is stable).
  static const addTaskSubmit = ValueKey<String>('e2e_add_task_submit');
}
