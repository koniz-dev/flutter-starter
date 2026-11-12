import 'package:flutter_starter/core/contracts/design_tokens_contracts.dart';
import 'package:flutter_starter/shared/design_system/tokens/app_colors.dart';
import 'package:flutter_starter/shared/design_system/tokens/default_design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Application theme configuration
class AppTheme {
  AppTheme._();

  /// The tokens both themes are built from by default.
  ///
  /// Typed on the contract, not on `DefaultDesignTokens`: to restyle the app,
  /// bind your own [AppDesignTokens] here, or build a theme from one with
  /// [light] or [dark].
  static const AppDesignTokens _tokens = DefaultDesignTokens();

  /// Dark-theme surface (cards, dialogs, app bar).
  static const _darkSurface = Color(0xFF1E1E1E);

  /// Dark-theme scaffold background.
  static const _darkBackground = Color(0xFF121212);

  /// Light theme, from the default tokens.
  static ThemeData get lightTheme => light(_tokens);

  /// Dark theme, from the default tokens.
  static ThemeData get darkTheme => dark(_tokens);

  /// A light theme built from [tokens].
  static ThemeData light(AppDesignTokens tokens) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: tokens.primary,
        secondary: tokens.secondary,
        surface: tokens.surface,
        error: tokens.error,
        onPrimary: tokens.textOnPrimary,
        // White, not textPrimary: #212529 on the #6C757D secondary fill is
        // 3.29:1, below AA for normal text.
        onSecondary: tokens.textOnPrimary,
        onSurface: tokens.textPrimary,
        // Secondary text (a completed task, a date). Unset, it fell back to
        // onSurface, so secondary text looked the same as primary text.
        onSurfaceVariant: tokens.textSecondary,
        onError: tokens.textOnPrimary,
      ),
      scaffoldBackgroundColor: tokens.background,
      textTheme: TextTheme(
        displayLarge: tokens.displayLarge,
        displayMedium: tokens.displayMedium,
        bodyLarge: tokens.bodyLarge,
        bodyMedium: tokens.bodyMedium,
        labelLarge: tokens.labelLarge,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.primary,
        foregroundColor: tokens.textOnPrimary,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.primary,
          foregroundColor: tokens.textOnPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: tokens.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: tokens.error),
        ),
      ),
    );
  }

  /// A dark theme built from [tokens].
  ///
  /// The dark surfaces, and the primary and error colours read as text on
  /// them, are fixed here rather than taken from [tokens]: the contract has
  /// no dark-surface members.
  static ThemeData dark(AppDesignTokens tokens) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        // Lighter than the light theme's: these are read as text on the dark
        // surfaces, where the light theme's primary and error fall below
        // 4.5:1. Filled buttons keep
        // tokens.primary through elevatedButtonTheme below.
        primary: AppColors.primaryOnDark,
        secondary: tokens.secondary,
        surface: _darkSurface,
        error: AppColors.errorOnDark,
        onPrimary: _darkBackground,
        onSecondary: tokens.textOnPrimary,
        // Set from tokens rather than inheriting the Material dark baseline,
        // which knows nothing about this palette.
        onSurface: tokens.textOnPrimary,
        onSurfaceVariant: tokens.textSecondaryOnDark,
        onError: _darkBackground,
      ),
      scaffoldBackgroundColor: _darkBackground,
      textTheme: TextTheme(
        displayLarge: tokens.displayLarge.copyWith(
          color: tokens.textOnPrimary,
        ),
        displayMedium: tokens.displayMedium.copyWith(
          color: tokens.textOnPrimary,
        ),
        bodyLarge: tokens.bodyLarge.copyWith(color: tokens.textOnPrimary),
        bodyMedium: tokens.bodyMedium.copyWith(
          color: tokens.textSecondaryOnDark,
        ),
        // The token is coloured for a light surface; invert it here.
        labelLarge: tokens.labelLarge.copyWith(color: tokens.textOnPrimary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.primary,
          foregroundColor: tokens.textOnPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: tokens.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.errorOnDark),
        ),
      ),
    );
  }
}
