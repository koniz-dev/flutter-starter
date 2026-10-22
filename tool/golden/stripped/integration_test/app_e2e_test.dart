import 'package:flutter/material.dart';
import 'package:flutter_starter/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

/// Boots the app and waits for the first frame.
///
/// Deliberately does NOT use `pumpAndSettle`, which cannot work on a device.
/// This is a property of the test binding, not of this app: `PatrolBinding`
/// extends `LiveTestWidgetsFlutterBinding`, whose `handleDrawFrame` calls
/// `platformDispatcher.scheduleFrame()` again after any frame the test did not
/// itself pump (`flutter_test/lib/src/binding.dart:2823-2825`, every policy but
/// `benchmark`). A frame is therefore always pending, so the
/// `do { pump } while (hasScheduledFrame)` loop inside `pumpAndSettle` never
/// exits and throws `pumpAndSettle timed out` however idle the app is.
///
/// Patrol's `waitUntilVisible` polls instead of demanding quiescence, so it is
/// unaffected. See `integration_test/README.md`.
Future<void> _boot(PatrolIntegrationTester $) async {
  await app.main();
  await $.pump(const Duration(seconds: 1));
}

/// Signs in and waits for the home screen.
///
/// With no backend - a debug build with `BASE_URL` unset - the login screen
/// offers the offline demo sign-in, and its fill button supplies the demo
/// account, so this runs with no server at all. Built with
/// `--dart-define=BASE_URL=<url>`, the demo is off and the sample credentials
/// go to that API, which must accept them.
Future<void> _submitLogin(PatrolIntegrationTester $) async {
  if ($(#e2e_demo_sign_in_fill).exists) {
    await $(#e2e_demo_sign_in_fill).tap();
  } else {
    await $(TextField).at(0).enterText('test@example.com');
    await $(TextField).at(1).enterText('password123');
  }
  await $(#e2e_login_submit).tap();
  await $(#e2e_home_content).waitUntilVisible();
}

void main() {
  // Runs everywhere, including with no backend. Not a token test: reaching a
  // rendered login screen exercises the native Patrol harness, app bootstrap,
  // the Riverpod scope, the router, and localization.
  patrolTest('E2E: app boots to a usable login screen', ($) async {
    await _boot($);

    await $(#e2e_login_submit).waitUntilVisible();
    expect($(#e2e_login_submit), findsOneWidget);

    await $(TextField).at(0).enterText('test@example.com');
    await $(TextField).at(1).enterText('password123');
    expect($('test@example.com'), findsOneWidget);
  });

  patrolTest(
    'E2E: auth -> home, stripped starter',
    ($) async {
      await _boot($);

      if ($(#e2e_login_submit).exists) {
        await _submitLogin($);
      }

      expect($(#e2e_home_content), findsOneWidget);
    },
  );
}
