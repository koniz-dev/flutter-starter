import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:flutter_starter/shared/accessibility/accessibility_constants.dart';

/// Accessibility helper functions
///
/// Provides utility functions for checking contrast ratios, calculating
/// accessible colors, and other accessibility-related operations.
class AccessibilityHelpers {
  AccessibilityHelpers._();

  /// Calculate the relative luminance of a color
  ///
  /// Returns a value between 0 (black) and 1 (white).
  /// Based on WCAG 2.1 guidelines.
  static double _getRelativeLuminance(Color color) {
    final r = _linearizeColorComponent(color.r);
    final g = _linearizeColorComponent(color.g);
    final b = _linearizeColorComponent(color.b);

    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Linearize a color component for luminance calculation
  static double _linearizeColorComponent(double component) {
    if (component <= 0.03928) {
      return component / 12.92;
    } else {
      return math.pow((component + 0.055) / 1.055, 2.4).toDouble();
    }
  }

  /// Calculate contrast ratio between two colors
  ///
  /// Returns a value between 1 (no contrast) and 21 (maximum contrast).
  /// WCAG 2.1 requires:
  /// - Normal text: 4.5:1 (AA) or 7:1 (AAA)
  /// - Large text: 3:1 (AA) or 4.5:1 (AAA)
  static double getContrastRatio(Color foreground, Color background) {
    final luminance1 = _getRelativeLuminance(foreground);
    final luminance2 = _getRelativeLuminance(background);

    final lighter = math.max(luminance1, luminance2);
    final darker = math.min(luminance1, luminance2);

    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Check if contrast ratio meets WCAG AA standards for normal text
  static bool meetsContrastRatioAA(
    Color foreground,
    Color background,
  ) {
    return getContrastRatio(foreground, background) >=
        AccessibilityConstants.minContrastRatioNormal;
  }

  /// Check if contrast ratio meets WCAG AA standards for large text
  static bool meetsContrastRatioAALarge(
    Color foreground,
    Color background,
  ) {
    return getContrastRatio(foreground, background) >=
        AccessibilityConstants.minContrastRatioLarge;
  }

  /// Check if contrast ratio meets WCAG AAA standards for normal text
  static bool meetsContrastRatioAAA(
    Color foreground,
    Color background,
  ) {
    return getContrastRatio(foreground, background) >=
        AccessibilityConstants.minContrastRatioEnhanced;
  }

  /// Get an accessible text color for a given background
  ///
  /// Returns black or white based on which provides better contrast.
  static Color getAccessibleTextColor(Color background) {
    final blackContrast = getContrastRatio(Colors.black, background);
    final whiteContrast = getContrastRatio(Colors.white, background);

    return blackContrast > whiteContrast ? Colors.black : Colors.white;
  }

  /// Ensure a widget has minimum touch target size
  ///
  /// Wraps the widget in a container with minimum size if needed.
  static Widget ensureMinTouchTarget(Widget child) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: AccessibilityConstants.minTouchTargetSize,
        minHeight: AccessibilityConstants.minTouchTargetSize,
      ),
      child: child,
    );
  }

  /// Get semantic label for a button based on its state
  ///
  /// Combines the base label with state information for screen readers.
  static String getButtonSemanticLabel(
    String baseLabel, {
    bool? isEnabled,
    bool? isLoading,
    String? additionalInfo,
  }) {
    final parts = <String>[];

    if (isLoading ?? false) {
      parts.add('Loading');
    }

    parts.add(baseLabel);

    if (!(isEnabled ?? true)) {
      parts.add('Disabled');
    }

    if (additionalInfo != null && additionalInfo.isNotEmpty) {
      parts.add(additionalInfo);
    }

    return parts.join(', ');
  }

  /// Get semantic value for a progress indicator
  ///
  /// Formats percentage for screen readers.
  static String getProgressSemanticValue(double value) {
    final percentage = (value * 100).round();
    return '$percentage percent';
  }
}
