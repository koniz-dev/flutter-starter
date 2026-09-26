import 'package:flutter/material.dart';
import 'package:flutter_starter/shared/design_system/tokens/app_typography.dart';
import 'package:flutter_test/flutter_test.dart';

// The fontSize/fontWeight expectations below were merged in from the duplicate
// test/shared/theme/app_text_styles_test.dart, which imported this same
// subject from a directory that mirrored nothing in lib/ and was named after
// `AppTextStyles`, a class that no longer exists. See
// koniz-dev/flutter-starter#184.
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

    test('should have displayLarge style', () {
      expect(AppTypography.displayLarge.fontSize, 32);
      expect(AppTypography.displayLarge.fontWeight, FontWeight.bold);
    });

    test('should have headlineMedium style', () {
      expect(AppTypography.headlineMedium.fontSize, 24);
      expect(AppTypography.headlineMedium.fontWeight, FontWeight.w600);
    });

    test('should have titleMedium style', () {
      expect(AppTypography.titleMedium.fontSize, 18);
      expect(AppTypography.titleMedium.fontWeight, FontWeight.w500);
    });

    test('should have bodyLarge style', () {
      expect(AppTypography.bodyLarge.fontSize, 16);
      expect(AppTypography.bodyLarge.fontWeight, FontWeight.normal);
    });

    test('should have bodyMedium style', () {
      expect(AppTypography.bodyMedium.fontSize, 14);
      expect(AppTypography.bodyMedium.fontWeight, FontWeight.normal);
    });

    test('should have labelButton style', () {
      expect(AppTypography.labelButton.fontSize, 14);
      expect(AppTypography.labelButton.fontWeight, FontWeight.w600);
    });
  });
}
