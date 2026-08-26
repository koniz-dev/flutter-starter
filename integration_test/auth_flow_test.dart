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

/// Enters the sample credentials and submits the login form.
Future<void> _submitLogin(PatrolIntegrationTester $) async {
  await $(TextField).at(0).enterText('test@example.com');
  await $(TextField).at(1).enterText('password123');
  await $(#e2e_login_submit).tap();
  await $.pumpAndSettle();
}

void main() {
  // Runs everywhere, including with no backend. Not a token test: reaching a
  // rendered login screen exercises the native Patrol harness, app bootstrap,
  // the Riverpod scope, the router, and localization.
  patrolTest('E2E: app boots to a usable login screen', ($) async {
    await app.main();
    await $.pumpAndSettle();

    await $(#e2e_login_submit).waitUntilVisible();
    expect($(#e2e_login_submit), findsOneWidget);

    await $(TextField).at(0).enterText('test@example.com');
    await $(TextField).at(1).enterText('password123');
    expect($('test@example.com'), findsOneWidget);
  });

  patrolTest(
    'auth flow: credentials reach home (requires a reachable backend)',
    ($) async {
      await app.main();
      await $.pumpAndSettle();

      if ($(#e2e_login_submit).exists) {
        await _submitLogin($);
      }

      expect($(#e2e_home_content), findsOneWidget);
    },
    skip: !hasBackend,
  );
}
