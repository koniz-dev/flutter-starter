import 'package:flutter/material.dart';
import 'package:flutter_starter/shared/design_system/tokens/default_design_tokens.dart';

/// Application theme configuration
class AppTheme {
  AppTheme._();
  static const _tokens = DefaultDesignTokens();

  /// Dark-theme surface (cards, dialogs, app bar).
  static const _darkSurface = Color(0xFF1E1E1E);

  /// Dark-theme scaffold background.
  static const _darkBackground = Color(0xFF121212);

  /// Light theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: _tokens.primary,
        secondary: _tokens.secondary,
        surface: _tokens.surface,
        error: _tokens.error,
        onPrimary: _tokens.textOnPrimary,
        // White, not textPrimary: #212529 on the #6C757D secondary fill is
        // 3.29:1, below AA for normal text.
        onSecondary: _tokens.textOnPrimary,
        onSurface: _tokens.textPrimary,
        onError: _tokens.textOnPrimary,
      ),
      scaffoldBackgroundColor: _tokens.background,
      textTheme: TextTheme(
        displayLarge: _tokens.displayLarge,
        displayMedium: _tokens.displayMedium,
        bodyLarge: _tokens.bodyLarge,
        bodyMedium: _tokens.bodyMedium,
        labelLarge: _tokens.labelLarge,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _tokens.primary,
        foregroundColor: _tokens.textOnPrimary,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _tokens.primary,
          foregroundColor: _tokens.textOnPrimary,
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
          borderSide: BorderSide(color: _tokens.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _tokens.error),
        ),
      ),
    );
  }

  /// Dark theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: _tokens.primary,
        secondary: _tokens.secondary,
        surface: _darkSurface,
        error: _tokens.error,
        onPrimary: _tokens.textOnPrimary,
        onSecondary: _tokens.textOnPrimary,
        // Set from tokens rather than inheriting the Material dark baseline,
        // which knows nothing about this palette.
        onSurface: _tokens.textOnPrimary,
        onError: _tokens.textOnPrimary,
      ),
      scaffoldBackgroundColor: _darkBackground,
      textTheme: TextTheme(
        displayLarge: _tokens.displayLarge.copyWith(
          color: _tokens.textOnPrimary,
        ),
        displayMedium: _tokens.displayMedium.copyWith(
          color: _tokens.textOnPrimary,
        ),
        bodyLarge: _tokens.bodyLarge.copyWith(color: _tokens.textOnPrimary),
        bodyMedium: _tokens.bodyMedium.copyWith(
          color: _tokens.textSecondaryOnDark,
        ),
        // The token is coloured for a light surface; invert it here.
        labelLarge: _tokens.labelLarge.copyWith(color: _tokens.textOnPrimary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _tokens.primary,
          foregroundColor: _tokens.textOnPrimary,
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
          borderSide: BorderSide(color: _tokens.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _tokens.error),
        ),
      ),
    );
  }
}
