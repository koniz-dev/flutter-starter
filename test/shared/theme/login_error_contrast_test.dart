// A validation error on LoginScreen must be readable: at least 4.5:1 against
// what it is painted on, in both themes.
//
// The error colour (#DC3545) read 4.30:1 on the light scaffold, and 4.14:1 on
// the dark one. This reads the colour the framework actually paints - from
// the RenderParagraph - rather than the token, so a theme that overrides
// errorStyle, or a widget that ignores the scheme, is caught too.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/accessibility/accessibility_constants.dart';
import 'package:flutter_starter/core/accessibility/accessibility_helpers.dart';
import 'package:flutter_starter/core/constants/ui_keys.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/shared/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  for (final (name, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    testWidgets('criterion 3 ($name): the rendered validation error meets '
        '4.5:1 on the scaffold', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: theme,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en')],
            home: const LoginScreen(),
          ),
        ),
      );

      // Submitting the empty form raises the validation errors.
      await tester.tap(find.byKey(UiKeys.loginSubmit));
      await tester.pumpAndSettle();

      final error = find.text(en.emailRequired);
      expect(error, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(error);
      final painted = paragraph.text.style!.color!;
      final background = theme.scaffoldBackgroundColor;

      final ratio = AccessibilityHelpers.getContrastRatio(painted, background);
      expect(
        ratio,
        greaterThanOrEqualTo(AccessibilityConstants.minContrastRatioNormal),
        reason:
            'validation error $painted on $background is '
            '${ratio.toStringAsFixed(2)}:1',
      );
    });
  }
}
