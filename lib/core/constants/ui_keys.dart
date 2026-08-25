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

  // The three keys below are NOT attached to any widget in this starter's
  // default `lib/`. `HomeScreen` is deliberately a minimal shell ("extend per
  // product"), so it offers no entry point into the sample `tasks` feature, and
  // the tasks screens do not key their controls.
  //
  // They are kept because they are the agreed selector names for a fork that
  // does add a tasks entry point, and because
  // `tool/golden/no_feature_flags/` wires `openTasks` in its own `HomeScreen`.
  // A fork must attach the key before writing a selector against it: Patrol
  // matches on the widget tree, so an unattached key silently finds nothing.

  /// Navigates from home to the tasks list.
  ///
  /// Intentionally unattached in the default starter - see the note above.
  /// Attach to your own home-to-tasks control when you add one.
  static const openTasks = ValueKey<String>('e2e_open_tasks');

  /// Tasks list FAB to add a task.
  ///
  /// Intentionally unattached in the default starter - see the note above.
  static const tasksFab = ValueKey<String>('e2e_tasks_fab');

  /// Confirms the create-task dialog (label is l10n-dependent; key is stable).
  ///
  /// Intentionally unattached in the default starter - see the note above.
  static const addTaskSubmit = ValueKey<String>('e2e_add_task_submit');
}
