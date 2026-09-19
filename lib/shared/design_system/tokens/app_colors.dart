import 'package:flutter/material.dart';

/// Semantic color tokens for the Design System.
///
/// Instead of using generic Colors.blue or Colors.red,
/// the app should use semantic colors like AppColors.primary
/// so it can be easily themed or dark-moded.
///
/// Every value here is chosen so that the foreground/background pairs the
/// themes build from them clear WCAG 2.1 AA
/// (`AccessibilityConstants.minContrastRatioNormal`, 4.5:1). The pairs are
/// pinned by `test/shared/theme/theme_contrast_test.dart`, so changing a value
/// below the line fails `flutter test`.
abstract class AppColors {
  // Brand Colors
  /// Primary brand color.
  ///
  /// Contrast budget: carries white text at 5.22:1 (AA), and is still 3.59:1
  /// against the dark scaffold `#121212`, so it also works as a non-text
  /// accent (focus rings, borders) in the dark theme.
  static const Color primary = Color(0xFF0069D9);

  /// Secondary brand color.
  ///
  /// Used as a fill behind [textInverse] (4.69:1). It is deliberately not the
  /// same value as [textSecondary]: a fill and a text colour have opposite
  /// contrast constraints.
  static const Color secondary = Color(0xFF6C757D);

  // Background and Surface
  /// Default background color for scaffolds
  static const Color background = Color(0xFFF8F9FA);

  /// Background color for cards and dialogs
  static const Color surface = Color(0xFFFFFFFF);

  // Text Colors
  /// Primary text color
  static const Color textPrimary = Color(0xFF212529);

  /// Secondary text color (muted).
  ///
  /// Reads at 5.89:1 on [background] and 6.21:1 on [surface].
  static const Color textSecondary = Color(0xFF5A6268);

  /// Inverse text color (light text on dark background)
  static const Color textInverse = Color(0xFFFFFFFF);

  /// Secondary (muted) text color for dark surfaces.
  ///
  /// Opaque on purpose. A translucent white such as `Colors.white70`
  /// composites differently on every background, and the WCAG contrast
  /// formula has no alpha channel, so it would score such a colour as pure
  /// white rather than as what is actually on screen.
  static const Color textSecondaryInverse = Color(0xFFADB5BD);

  // Status Colors
  /// Success state color (valid input, success alerts).
  ///
  /// Used both as a fill behind [textInverse] (5.14:1) and as a foreground on
  /// [background] (4.87:1).
  static const Color success = Color(0xFF1E7E34);

  /// Warning state color.
  ///
  /// A fill only: it is paired with [textPrimary] (9.46:1). At 1.55:1 against
  /// [background] it must never be used as a text or icon colour on a light
  /// surface.
  static const Color warning = Color(0xFFFFC107);

  /// Error state color (invalid input, error alerts).
  ///
  /// Carries [textInverse] at 4.53:1.
  static const Color error = Color(0xFFDC3545);

  /// Informational state color.
  ///
  /// Fill behind [textInverse] (5.02:1); also legible as a foreground on
  /// [background] (4.77:1).
  static const Color info = Color(0xFF117A8B);
}
