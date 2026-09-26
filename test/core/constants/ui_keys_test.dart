// Criterion 5 of #53: the E2E selector contract, asserted in the gating tier.
//
// `UiKeys` is the set of stable selectors `integration_test/` (Patrol) matches
// on. Until this file existed, `homeContent` was asserted only in
// `test/acceptance/` (tagged `golden`, skipped by default), `loginSubmit` only
// under Patrol (which CI cannot run), and `registerSubmit` nowhere at all -
// so every `key:` in `lib/` could be deleted and `flutter test` stayed green.
//
// These tests run under plain `flutter test`. Removing a `key:` from one of
// the three widgets below fails the default suite.

import 'package:flutter/material.dart';
import 'package:flutter_starter/core/constants/ui_keys.dart';
import 'package:flutter_starter/features/auth/di/auth_providers.dart';
import 'package:flutter_starter/features/auth/domain/usecases/login_usecase.dart';
import 'package:flutter_starter/features/auth/domain/usecases/register_usecase.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/features/auth/presentation/screens/register_screen.dart';
import 'package:flutter_starter/features/home/presentation/screens/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/pump_app.dart';

class _MockLoginUseCase extends Mock implements LoginUseCase {}

class _MockRegisterUseCase extends Mock implements RegisterUseCase {}

void main() {
  group('UiKeys are attached to the widgets E2E selectors target', () {
    testWidgets('loginSubmit is on the login screen primary action', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const LoginScreen(),
        overrides: [
          loginUseCaseProvider.overrideWithValue(_MockLoginUseCase()),
        ],
      );

      final keyed = find.byKey(UiKeys.loginSubmit);
      expect(
        keyed,
        findsOneWidget,
        reason: 'UiKeys.loginSubmit is the Patrol selector #e2e_login_submit',
      );
      // The key must sit on the submit button, not on some nearby wrapper:
      // a selector that taps the wrong widget is as broken as a missing one.
      expect(
        tester.widget<ElevatedButton>(keyed).onPressed,
        isNotNull,
        reason: 'the keyed widget must be the enabled submit button',
      );
    });

    testWidgets('registerSubmit is on the register screen primary action', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const RegisterScreen(),
        overrides: [
          registerUseCaseProvider.overrideWithValue(_MockRegisterUseCase()),
        ],
      );

      final keyed = find.byKey(UiKeys.registerSubmit);
      expect(keyed, findsOneWidget);
      expect(tester.widget<ElevatedButton>(keyed).onPressed, isNotNull);
    });

    testWidgets('homeContent wraps the home screen body', (tester) async {
      await pumpApp(tester, const HomeScreen());

      expect(find.byKey(UiKeys.homeContent), findsOneWidget);
      expect(
        tester.widget(find.byKey(UiKeys.homeContent)),
        isA<RepaintBoundary>(),
      );
    });
  });

  group('UiKeys value contract', () {
    // Patrol selectors are written as `$(#e2e_login_submit)`, i.e. against the
    // string, not the Dart symbol. Renaming a value silently breaks every
    // selector in integration_test/ and in any fork's test suite.
    test('key strings are the documented e2e_* names', () {
      expect(UiKeys.loginSubmit.value, 'e2e_login_submit');
      expect(UiKeys.registerSubmit.value, 'e2e_register_submit');
      expect(UiKeys.homeContent.value, 'e2e_home_content');
      expect(UiKeys.openTasks.value, 'e2e_open_tasks');
      expect(UiKeys.tasksFab.value, 'e2e_tasks_fab');
      expect(UiKeys.addTaskSubmit.value, 'e2e_add_task_submit');
    });
  });
}
