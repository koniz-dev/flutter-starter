// A flag tile's source chip and "Updated" time sat in a Row, which
// overflowed a 360dp phone at a large text size. They wrap now.
//
// Real-font widths fit at 2.0x after wrapping; the test font (Ahem) draws
// every glyph a full em wide, so the chip alone exceeds the row at 2.0x
// here. 1.3x is where the Row overflowed and Ahem still fits one item a line.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/features/feature_flags/domain/entities/feature_flag.dart';
import 'package:flutter_starter/features/feature_flags/presentation/providers/feature_flags_providers.dart';
import 'package:flutter_starter/features/feature_flags/presentation/screens/feature_flags_debug_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final scale in [1.0, 1.3]) {
    testWidgets('a flag tile at 360dp and ${scale}x text does not overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allFeatureFlagsProvider.overrideWith(
              (ref) async => {
                'enable_new_feature': FeatureFlag(
                  key: 'enable_new_feature',
                  value: true,
                  source: FeatureFlagSource.localOverride,
                  lastUpdated: DateTime(2026, 1, 1, 12, 34),
                ),
              },
            ),
            featureFlagsInitializationProvider.overrideWith((ref) async {}),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: FeatureFlagsDebugScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Features'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(Chip), findsOneWidget);
      expect(find.textContaining('Updated'), findsOneWidget);
    });
  }
}
