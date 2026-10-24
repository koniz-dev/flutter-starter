@Tags(['golden'])
library;

import 'package:flutter_starter/core/constants/ui_keys.dart';
import 'package:flutter_starter/features/auth/demo/demo_auth.dart';
import 'package:flutter_starter/features/auth/demo/demo_sign_in_card.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/shared/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

import 'acceptance_helpers.dart';

void main() {
  group('LoginScreen with the offline demo sign-in', () {
    setUp(() => DemoAuth.debugEnabledOverride = true);
    tearDown(() => DemoAuth.debugEnabledOverride = false);

    for (final (name, theme) in [
      ('light', AppTheme.lightTheme),
      ('dark', AppTheme.darkTheme),
    ]) {
      testWidgets('$name theme: the demo card and its fill button', (
        tester,
      ) async {
        await pumpAcceptance(tester, const LoginScreen(), theme: theme);

        // Wording is asserted with finders; the golden shows layout and colour.
        expect(find.byType(DemoSignInCard), findsOneWidget);
        expect(find.byKey(UiKeys.demoSignInFill), findsOneWidget);
        expect(find.text('Demo mode'), findsOneWidget);

        await captureAcceptanceGolden(
          find.byType(LoginScreen),
          'login_demo_$name',
        );
      });
    }
  });
}
