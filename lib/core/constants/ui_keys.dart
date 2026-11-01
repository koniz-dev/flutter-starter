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

  /// Fills the login form with the demo account. Present only while the app
  /// signs in offline because no backend is configured.
  static const demoSignInFill = ValueKey<String>('e2e_demo_sign_in_fill');

  /// Home body after authentication (works for full and stripped home UIs).
  static const homeContent = ValueKey<String>('e2e_home_content');

  /// Sign-out action in the home app bar.
  static const homeSignOut = ValueKey<String>('e2e_home_sign_out');

  /// Home entry that opens the destination with this id.
  static ValueKey<String> homeDestination(String id) =>
      ValueKey<String>('e2e_home_destination_$id');
}
