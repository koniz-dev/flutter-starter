import 'package:flutter/material.dart';
import 'package:flutter_starter/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

/// Whether a reachable backend is configured for this run.
///
/// Pass `--dart-define=E2E_BACKEND=true` when you have an API. The sample auth
/// flow POSTs to `BASE_URL`; with no server the login call fails, the app stays
/// on the login screen, and every assertion past login is unreachable. Those
/// assertions are skipped rather than shipped permanently red - a starter whose
/// E2E suite is red by construction teaches people to ignore it.
const hasBackend = bool.fromEnvironment('E2E_BACKEND');

/// Boots the app and waits for the first frame.
///
/// Deliberately does NOT use `pumpAndSettle`. On a real device it times out
/// whenever the tree never reaches an idle frame, which is what happened here:
/// `pumpAndSettle timed out` after 131s with the app running fine. Patrol's
/// `waitUntilVisible` polls instead of demanding quiescence, so it tolerates
/// any ongoing platform or animation activity.
Future<void> _boot(PatrolIntegrationTester $) async {
  await app.main();
  await $.pump(const Duration(seconds: 1));
}

/// Enters the sample credentials and submits the login form.
Future<void> _submitLogin(PatrolIntegrationTester $) async {
  await $(TextField).at(0).enterText('test@example.com');
  await $(TextField).at(1).enterText('password123');
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
    'E2E: auth -> home, no tasks (requires a reachable backend)',
    ($) async {
      await _boot($);

      if ($(#e2e_login_submit).exists) {
        await _submitLogin($);
      }

      expect($(#e2e_home_content), findsOneWidget);
    },
    skip: !hasBackend,
  );
}
