import 'package:flutter/material.dart';
import 'package:flutter_starter/core/contracts/design_tokens_contracts.dart';
import 'package:flutter_starter/shared/design_system/tokens/app_colors.dart';
import 'package:flutter_starter/shared/design_system/tokens/app_typography.dart';

/// Default semantic token implementation for the starter.
///
/// Maps contract-level semantic tokens to default starter values.
class DefaultDesignTokens implements AppDesignTokens {
  /// Creates the default semantic token mapping for starter theme.
  const DefaultDesignTokens();

  @override
  Color get primary => AppColors.primary;

  @override
  Color get secondary => AppColors.secondary;

  @override
  Color get background => AppColors.background;

  @override
  Color get surface => AppColors.surface;

  @override
  Color get error => AppColors.error;

  @override
  Color get textPrimary => AppColors.textPrimary;

  @override
  Color get textSecondary => AppColors.textSecondary;

  @override
  Color get textOnPrimary => AppColors.textInverse;

  @override
  Color get textSecondaryOnDark => AppColors.textSecondaryInverse;

  @override
  Color get success => AppColors.success;

  @override
  Color get warning => AppColors.warning;

  @override
  Color get info => AppColors.info;

  @override
  TextStyle get displayLarge => AppTypography.displayLarge;

  @override
  TextStyle get displayMedium => AppTypography.headlineMedium;

  @override
  TextStyle get bodyLarge => AppTypography.bodyLarge;

  @override
  TextStyle get bodyMedium => AppTypography.bodyMedium;

  /// Label style as it appears in a `TextTheme`.
  ///
  /// Coloured with [textPrimary], not [textOnPrimary]: a `TextTheme` entry is
  /// rendered against the scaffold background, so white here is white on
  /// `#F8F9FA` (1.05:1). Buttons stay legible because the button themes set
  /// their own `foregroundColor` from [textOnPrimary], and the dark theme
  /// overrides this colour for its own background.
  @override
  TextStyle get labelLarge =>
      AppTypography.labelButton.copyWith(color: textPrimary);
}
