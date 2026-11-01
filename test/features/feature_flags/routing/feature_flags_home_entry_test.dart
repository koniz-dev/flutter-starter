import 'package:flutter/foundation.dart';
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

  testWidgets('with debug routes on, home opens the flags screen', (
    tester,
  ) async {
    await pumpSignedInApp(
      tester,
      overrides: [
        homeDestinationsProvider.overrideWithValue(
          buildHomeDestinations(debugRoutes: true),
        ),
      ],
    );

    await tester.tap(find.byKey(_entry));
    await tester.pumpAndSettle();

    expect(find.byType(FeatureFlagsDebugScreen), findsOneWidget);
  });

  testWidgets('with debug routes off, home shows no entry for it', (
    tester,
  ) async {
    await pumpSignedInApp(
      tester,
      overrides: [
        homeDestinationsProvider.overrideWithValue(
          buildHomeDestinations(debugRoutes: false),
        ),
      ],
    );

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byKey(_entry), findsNothing);
  });
}
