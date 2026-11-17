// RouteNotFoundScreen was a Column with no scroll view: in landscape at a
// large text size, or with a long location (the link is echoed on screen),
// it overflowed.

import 'package:flutter_starter/core/routing/route_not_found_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final (length, scale) in [(60, 2.0), (400, 1.0), (4000, 2.0)]) {
    testWidgets('a $length-character location at ${scale}x text in 640x360 '
        'does not overflow', (tester) async {
      tester.view.physicalSize = const Size(640, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: RouteNotFoundScreen(location: '/${'a' * length}'),
        ),
      );

      expect(tester.takeException(), isNull);
      // The way home stays reachable.
      await tester.scrollUntilVisible(
        find.byType(FilledButton),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(FilledButton).hitTestable(), findsOneWidget);
    });
  }
}
