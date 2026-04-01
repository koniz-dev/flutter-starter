import 'package:flutter/material.dart';

/// Semantic color tokens for the Design System.
///
/// Instead of using generic Colors.blue or Colors.red,
/// the app should use semantic colors like AppColors.primary
/// so it can be easily themed or dark-moded.
abstract class AppColors {
  // Brand Colors
  /// Primary brand color
  static const Color primary = Color(0xFF007BFF);

  /// Darker variant of primary color
  static const Color primaryDark = Color(0xFF0056b3);

  /// Secondary brand color
  static const Color secondary = Color(0xFF6C757D);

  /// Accent or highlight color
  static const Color accent = Color(0xFFFFC107);

  // Background and Surface
  /// Default background color for scaffolds
  static const Color background = Color(0xFFF8F9FA);

  /// Background color for cards and dialogs
  static const Color surface = Color(0xFFFFFFFF);

  // Text Colors
  /// Primary text color
  static const Color textPrimary = Color(0xFF212529);

  /// Secondary text color (muted)
  static const Color textSecondary = Color(0xFF6C757D);

  /// Inverse text color (light text on dark background)
  static const Color textInverse = Color(0xFFFFFFFF);

  // Status Colors
  /// Success state color (valid input, success alerts)
  static const Color success = Color(0xFF28A745);

  /// Warning state color
  static const Color warning = Color(0xFFFFC107);

  /// Error state color (invalid input, error alerts)
  static const Color error = Color(0xFFDC3545);

  /// Informational state color
  static const Color info = Color(0xFF17A2B8);
}
