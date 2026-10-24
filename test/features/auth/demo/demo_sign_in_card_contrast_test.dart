// The demo card's controls must be readable against the card in both shipped
// themes: the fill button is the one control the offline demo flow depends on.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_starter/core/accessibility/accessibility_constants.dart';
import 'package:flutter_starter/core/accessibility/accessibility_helpers.dart';
import 'package:flutter_starter/core/constants/ui_keys.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/features/auth/demo/demo_sign_in_card.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/shared/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final themes = {
    'light': AppTheme.lightTheme,
    'dark': AppTheme.darkTheme,
  };

  for (final MapEntry(key: name, value: theme) in themes.entries) {
    testWidgets('$name theme: the fill button reads against the card', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: LocalizationService.supportedLocales,
          home: Scaffold(body: DemoSignInCard(onFill: () {})),
        ),
      );

      final card = tester.widget<Card>(find.byType(Card)).color!;
      final button = find.byKey(UiKeys.demoSignInFill);
      final label = tester.element(
        find.descendant(of: button, matching: find.byType(Text)),
      );
      final labelColor = DefaultTextStyle.of(label).style.color!;
      final style = tester.widget<OutlinedButton>(button).style;
      final outline =
          style?.side?.resolve(<WidgetState>{})?.color ??
          theme.colorScheme.outline;

      expect(
        AccessibilityHelpers.getContrastRatio(labelColor, card),
        greaterThanOrEqualTo(AccessibilityConstants.minContrastRatioNormal),
        reason: 'label $labelColor on card $card',
      );
      // A control's boundary needs 3:1 (WCAG 1.4.11 non-text contrast).
      expect(
        AccessibilityHelpers.getContrastRatio(outline, card),
        greaterThanOrEqualTo(AccessibilityConstants.minContrastRatioLarge),
        reason: 'outline $outline on card $card',
      );
    });
  }
}
