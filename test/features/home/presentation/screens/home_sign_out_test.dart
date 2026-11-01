import 'package:flutter_starter/core/constants/ui_keys.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/features/home/presentation/screens/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/signed_in_app.dart';

void main() {
  testWidgets('signing out from home clears the session and lands on login', (
    tester,
  ) async {
    final app = await pumpSignedInApp(tester);
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.byKey(UiKeys.homeSignOut));
    await tester.pumpAndSettle();

    expect(app.router.routeInformationProvider.value.uri.path, AppRoutes.login);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(app.container.read(authProvider).user, isNull);
    expect(app.session.token, isNull);
    expect(app.session.refresh, isNull);
    expect(app.session.user, isNull);
  });
}
