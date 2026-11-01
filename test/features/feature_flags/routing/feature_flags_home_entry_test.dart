// Run this file twice to see both sides of the debug gate:
//   flutter test <this file>
//   flutter test <this file> --dart-define=ENABLE_DEBUG_FEATURES=false

import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/constants/ui_keys.dart';
import 'package:flutter_starter/core/routing/routes_registry.dart';
import 'package:flutter_starter/features/feature_flags/presentation/screens/feature_flags_debug_screen.dart';
import 'package:flutter_starter/features/feature_flags/routing/feature_flags_routes.dart';
import 'package:flutter_starter/features/home/presentation/screens/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/signed_in_app.dart';

final ValueKey<String> _entry = UiKeys.homeDestination(
  featureFlagsHomeDestination.id,
);

void main() {
  test('the entry is listed only when debug routes are on', () {
    expect(
      buildHomeDestinations(debugRoutes: true),
      contains(featureFlagsHomeDestination),
    );
    expect(
      buildHomeDestinations(debugRoutes: false),
      isNot(contains(featureFlagsHomeDestination)),
    );
  });

  // Home and the router both read AppConfig.enableDebugFeatures, so the app
  // as built shows the entry exactly when the route exists.
  testWidgets('home shows the flags entry exactly when the route is '
      'registered (enableDebugFeatures=${AppConfig.enableDebugFeatures}), '
      'and the entry opens it', (tester) async {
    await pumpSignedInApp(tester);
    expect(find.byType(HomeScreen), findsOneWidget);

    if (!AppConfig.enableDebugFeatures) {
      expect(find.byKey(_entry), findsNothing);
      return;
    }
    await tester.tap(find.byKey(_entry));
    await tester.pumpAndSettle();
    expect(find.byType(FeatureFlagsDebugScreen), findsOneWidget);
  });
}
