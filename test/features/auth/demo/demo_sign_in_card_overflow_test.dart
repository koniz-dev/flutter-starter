// The demo card's title sat in a Row without room to wrap: Arabic at twice
// the text size overflowed a 360dp-wide phone. Every shipped locale must fit
// at that size.

import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/features/auth/demo/demo_sign_in_card.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final locale in LocalizationService.supportedLocales) {
    testWidgets('$locale at 2x text fits a 360dp screen', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: LocalizationService.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: DemoSignInCard(onFill: () {}),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  }
}
