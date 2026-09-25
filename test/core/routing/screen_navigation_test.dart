import 'package:flutter/material.dart';
import 'package:flutter_starter/core/constants/ui_keys.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/features/auth/presentation/screens/register_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/pump_app.dart';

// Screen-level navigation, driven through the *app's* router rather than a
// router assembled in this file. `login_screen.dart` and `register_screen.dart`
// called `context.go` and `context.pop` from `package:go_router` directly
// until #177 moved them onto `NavigationExtensions`; the point of these tests
// is that the move changed nothing a user can observe.
//
// Only auth routes are exercised here, because every strip variant keeps the
// auth sample. The tasks half of the same change is covered by
// `test/features/tasks/presentation/screens/task_detail_navigation_test.dart`,
// which the strip deletes along with the feature.

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(this._initial);

  final AuthState _initial;

  @override
  AuthState build() => _initial;
}

void main() {
  String locationOf(GoRouter router) => router.state.uri.toString();

  testWidgets('login screen link renders the register screen', (tester) async {
    final router = await pumpAppRouter(
      tester,
      overrides: [
        authNotifierProvider.overrideWith(
          () => _TestAuthNotifier(const AuthState()),
        ),
        sessionRestorationProvider.overrideWith((ref) async {}),
      ],
    );
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byKey(UiKeys.loginSubmit), findsOneWidget);

    // The only TextButton on the login screen is the register link.
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    expect(locationOf(router), AppRoutes.register);
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.byKey(UiKeys.registerSubmit), findsOneWidget);
  });

  testWidgets('register screen link returns to the login screen', (
    tester,
  ) async {
    final router = await pumpAppRouter(
      tester,
      overrides: [
        authNotifierProvider.overrideWith(
          () => _TestAuthNotifier(const AuthState()),
        ),
        sessionRestorationProvider.overrideWith((ref) async {}),
      ],
    );
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(find.byKey(UiKeys.registerSubmit), findsOneWidget);

    // `go` leaves nothing to pop, so this exercises the fallback branch.
    expect(router.canPop(), isFalse);
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    expect(locationOf(router), AppRoutes.login);
    expect(find.byKey(UiKeys.loginSubmit), findsOneWidget);
  });
}
