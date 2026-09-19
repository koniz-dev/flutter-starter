import 'package:flutter/material.dart';
import 'package:flutter_starter/core/contracts/design_tokens_contracts.dart';
import 'package:flutter_starter/shared/design_system/tokens/app_colors.dart';
import 'package:flutter_starter/shared/design_system/tokens/app_typography.dart';
import 'package:flutter_starter/shared/design_system/tokens/default_design_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tokens = DefaultDesignTokens();

  group('DefaultDesignTokens', () {
    test('implements the AppDesignTokens contract', () {
      expect(tokens, isA<AppDesignTokens>());
    });

    group('colour mappings', () {
      test('primary -> AppColors.primary', () {
        expect(tokens.primary, AppColors.primary);
      });

      test('secondary -> AppColors.secondary', () {
        expect(tokens.secondary, AppColors.secondary);
      });

      test('background -> AppColors.background', () {
        expect(tokens.background, AppColors.background);
      });

      test('surface -> AppColors.surface', () {
        expect(tokens.surface, AppColors.surface);
      });

      test('error -> AppColors.error', () {
        expect(tokens.error, AppColors.error);
      });

      test('textPrimary -> AppColors.textPrimary', () {
        expect(tokens.textPrimary, AppColors.textPrimary);
      });

      test('textSecondary -> AppColors.textSecondary', () {
        expect(tokens.textSecondary, AppColors.textSecondary);
      });

      test('textOnPrimary -> AppColors.textInverse (names differ)', () {
        expect(tokens.textOnPrimary, AppColors.textInverse);
      });

      test('textSecondaryOnDark -> AppColors.textSecondaryInverse', () {
        expect(tokens.textSecondaryOnDark, AppColors.textSecondaryInverse);
      });

      test('success -> AppColors.success', () {
        expect(tokens.success, AppColors.success);
      });

      test('warning -> AppColors.warning', () {
        expect(tokens.warning, AppColors.warning);
      });

      test('info -> AppColors.info', () {
        expect(tokens.info, AppColors.info);
      });
    });

    group('typography mappings', () {
      test('displayLarge -> AppTypography.displayLarge', () {
        expect(tokens.displayLarge, AppTypography.displayLarge);
      });

      test('displayMedium -> AppTypography.headlineMedium (names differ)', () {
        // The non-obvious one: the contract's "displayMedium" slot is filled by
        // the 24px headlineMedium style, not by any displayMedium token.
        expect(tokens.displayMedium, AppTypography.headlineMedium);
        expect(tokens.displayMedium.fontSize, 24);
        expect(tokens.displayMedium, isNot(AppTypography.displayLarge));
      });

      test('bodyLarge -> AppTypography.bodyLarge', () {
        expect(tokens.bodyLarge, AppTypography.bodyLarge);
      });

      test('bodyMedium -> AppTypography.bodyMedium', () {
        expect(tokens.bodyMedium, AppTypography.bodyMedium);
      });

      test('labelLarge -> labelButton recoloured with textPrimary', () {
        // labelButton itself carries no colour; the token supplies one. It must
        // be textPrimary, because a TextTheme entry is painted on the scaffold
        // background, not on a button fill.
        expect(AppTypography.labelButton.color, isNull);
        expect(
          tokens.labelLarge,
          AppTypography.labelButton.copyWith(color: AppColors.textPrimary),
        );
        expect(tokens.labelLarge.color, AppColors.textPrimary);
        expect(tokens.labelLarge.fontSize, AppTypography.labelButton.fontSize);
        expect(
          tokens.labelLarge.fontWeight,
          AppTypography.labelButton.fontWeight,
        );
      });
    });

    test('every colour token is opaque', () {
      // Contrast maths has no alpha channel; a translucent token would make
      // every ratio in test/shared/theme/theme_contrast_test.dart a fiction.
      final colors = <String, Color>{
        'primary': tokens.primary,
        'secondary': tokens.secondary,
        'background': tokens.background,
        'surface': tokens.surface,
        'error': tokens.error,
        'textPrimary': tokens.textPrimary,
        'textSecondary': tokens.textSecondary,
        'textOnPrimary': tokens.textOnPrimary,
        'textSecondaryOnDark': tokens.textSecondaryOnDark,
        'success': tokens.success,
        'warning': tokens.warning,
        'info': tokens.info,
      };
      for (final entry in colors.entries) {
        expect(entry.value.a, 1.0, reason: '${entry.key} must be opaque');
      }
    });
  });
}
