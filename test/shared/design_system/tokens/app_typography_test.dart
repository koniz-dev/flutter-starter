import 'package:flutter/material.dart';
import 'package:flutter_starter/shared/design_system/tokens/app_typography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTypography Properties Test', () {
    test('No token declares a fontFamily', () {
      // The starter bundles no font, so every token deliberately leaves
      // fontFamily null and inherits the platform default. See the class doc
      // on AppTypography and test/shared/theme/app_theme_font_family_test.dart.
      const styles = <String, TextStyle>{
        'displayLarge': AppTypography.displayLarge,
        'headlineMedium': AppTypography.headlineMedium,
        'titleMedium': AppTypography.titleMedium,
        'bodyLarge': AppTypography.bodyLarge,
        'bodyMedium': AppTypography.bodyMedium,
        'labelButton': AppTypography.labelButton,
      };
      styles.forEach((name, style) {
        expect(
          style.fontFamily,
          isNull,
          reason: 'AppTypography.$name must not pin a font family',
        );
        expect(
          style.fontFamilyFallback,
          isNull,
          reason: 'AppTypography.$name must not pin a font family fallback',
        );
      });
    });

    test('Should expose TextStyle definitions', () {
      expect(AppTypography.displayLarge, isA<TextStyle>());
      expect(AppTypography.headlineMedium, isA<TextStyle>());
      expect(AppTypography.titleMedium, isA<TextStyle>());
      expect(AppTypography.bodyLarge, isA<TextStyle>());
      expect(AppTypography.bodyMedium, isA<TextStyle>());
      expect(AppTypography.labelButton, isA<TextStyle>());
    });
  });
}
