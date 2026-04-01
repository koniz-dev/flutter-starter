import 'package:flutter/material.dart';
import 'package:flutter_starter/shared/design_system/tokens/default_design_tokens.dart';

/// Application theme configuration
class AppTheme {
  AppTheme._();
  static const _tokens = DefaultDesignTokens();

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
        onSecondary: _tokens.textPrimary,
        onSurface: _tokens.textPrimary,
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
        surface: const Color(0xFF1E1E1E),
        error: _tokens.error,
        onPrimary: _tokens.textOnPrimary,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      textTheme: TextTheme(
        displayLarge: _tokens.displayLarge.copyWith(color: Colors.white),
        displayMedium: _tokens.displayMedium.copyWith(color: Colors.white),
        bodyLarge: _tokens.bodyLarge.copyWith(color: Colors.white),
        bodyMedium: _tokens.bodyMedium.copyWith(color: Colors.white70),
        labelLarge: _tokens.labelLarge,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
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
