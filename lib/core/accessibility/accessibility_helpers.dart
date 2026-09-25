import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:flutter_starter/core/accessibility/accessibility_constants.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';

/// Accessibility helper functions
///
/// Provides utility functions for checking contrast ratios, calculating
/// accessible colors, and other accessibility-related operations.
class AccessibilityHelpers {
  AccessibilityHelpers._();

  /// Calculate the relative luminance of an opaque colour
  ///
  /// Takes already-composited sRGB channels in the 0..1 range and returns a
  /// value between 0 (black) and 1 (white), per WCAG 2.1. The WCAG formula is
  /// defined for opaque colours only, which is why callers must composite
  /// first - see [getContrastRatio].
  static double _relativeLuminance(double red, double green, double blue) {
    final r = _linearizeColorComponent(red);
    final g = _linearizeColorComponent(green);
    final b = _linearizeColorComponent(blue);

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

  /// Composite [foreground] over an opaque [background]
  ///
  /// Source-over alpha blending in the gamma-encoded sRGB space, which is what
  /// the framework paints and therefore what the user actually sees:
  /// `out = fg * fg.a + bg * (1 - fg.a)`. Linearising before blending would
  /// produce a colour the renderer never draws.
  ///
  /// Returns the composited channels as `(red, green, blue)` in 0..1. When
  /// `foreground.a` is 1 this is the identity, so opaque colours are scored
  /// exactly as they were before alpha was honoured.
  static (double, double, double) _compositeOver(
    Color foreground,
    Color background,
  ) {
    final alpha = foreground.a.clamp(0.0, 1.0);
    if (alpha == 1.0) {
      return (foreground.r, foreground.g, foreground.b);
    }

    return (
      foreground.r * alpha + background.r * (1 - alpha),
      foreground.g * alpha + background.g * (1 - alpha),
      foreground.b * alpha + background.b * (1 - alpha),
    );
  }

  /// Calculate contrast ratio between two colors
  ///
  /// Returns a value between 1 (no contrast) and 21 (maximum contrast).
  /// WCAG 2.1 requires:
  /// - Normal text: 4.5:1 (AA) or 7:1 (AAA)
  /// - Large text: 3:1 (AA) or 4.5:1 (AAA)
  ///
  /// ## Alpha semantics
  ///
  /// The WCAG relative-luminance formula is defined for opaque colours only.
  /// This method therefore takes the two halves of the problem differently:
  ///
  /// - **A translucent [foreground] is composited over [background]** before
  ///   being measured, so the ratio describes the pixel the user sees rather
  ///   than the pixel the token declares. `Colors.white70` on `#121212` scores
  ///   9.48:1, not the 18.73:1 opaque white would score.
  /// - **A translucent [background] is rejected** with an [ArgumentError].
  ///   There is no way to composite it: whatever sits behind it was never
  ///   supplied, and inventing a backdrop would return a number that is wrong
  ///   in a way the caller cannot see. Failing loudly is the only honest
  ///   option. Pass the opaque colour that is actually painted underneath -
  ///   usually the scaffold or surface colour.
  ///
  /// Compositing was chosen over rejecting both sides because the useful
  /// question is "what does the reader perceive", and a translucent foreground
  /// on a known backdrop answers it exactly. For callers this means a
  /// translucent foreground now returns a lower, truthful ratio where it
  /// previously returned the opaque one, and a translucent background - which
  /// no caller in this repository passes - now throws instead of silently
  /// lying.
  ///
  /// Throws an [ArgumentError] if `background.a` is not 1.
  static double getContrastRatio(Color foreground, Color background) {
    if (background.a != 1.0) {
      throw ArgumentError.value(
        background,
        'background',
        'must be opaque: a contrast ratio against a translucent background is '
            'undefined, because the colour painted behind it is unknown. Pass '
            'the opaque colour that is actually painted underneath.',
      );
    }

    final (r, g, b) = _compositeOver(foreground, background);

    final luminance1 = _relativeLuminance(r, g, b);
    final luminance2 = _relativeLuminance(
      background.r,
      background.g,
      background.b,
    );

    final lighter = math.max(luminance1, luminance2);
    final darker = math.min(luminance1, luminance2);

    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Check if contrast ratio meets WCAG AA standards for normal text
  ///
  /// A translucent [foreground] is composited over [background] first, and a
  /// translucent [background] throws - see [getContrastRatio] for why.
  static bool meetsContrastRatioAA(Color foreground, Color background) {
    return getContrastRatio(foreground, background) >=
        AccessibilityConstants.minContrastRatioNormal;
  }

  /// Check if contrast ratio meets WCAG AA standards for large text
  ///
  /// A translucent [foreground] is composited over [background] first, and a
  /// translucent [background] throws - see [getContrastRatio] for why.
  static bool meetsContrastRatioAALarge(Color foreground, Color background) {
    return getContrastRatio(foreground, background) >=
        AccessibilityConstants.minContrastRatioLarge;
  }

  /// Check if contrast ratio meets WCAG AAA standards for normal text
  ///
  /// A translucent [foreground] is composited over [background] first, and a
  /// translucent [background] throws - see [getContrastRatio] for why.
  static bool meetsContrastRatioAAA(Color foreground, Color background) {
    return getContrastRatio(foreground, background) >=
        AccessibilityConstants.minContrastRatioEnhanced;
  }

  /// Get an accessible text color for a given background
  ///
  /// Returns black or white based on which provides better contrast.
  ///
  /// [background] must be opaque; see [getContrastRatio].
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
  /// Combines the base label with state information for screen readers. The
  /// state words come from [l10n] so a screen reader in any supported locale
  /// announces them in that locale - pass `context.l10n`.
  static String getButtonSemanticLabel(
    String baseLabel, {
    required AppLocalizations l10n,
    bool? isEnabled,
    bool? isLoading,
    String? additionalInfo,
  }) {
    final parts = <String>[];

    if (isLoading ?? false) {
      parts.add(l10n.stateLoading);
    }

    parts.add(baseLabel);

    if (!(isEnabled ?? true)) {
      parts.add(l10n.stateDisabled);
    }

    if (additionalInfo != null && additionalInfo.isNotEmpty) {
      parts.add(additionalInfo);
    }

    return parts.join(', ');
  }

  /// Get semantic value for a progress indicator
  ///
  /// Formats the percentage for screen readers using [l10n], so the wording
  /// follows the active locale - pass `context.l10n`.
  static String getProgressSemanticValue(
    double value, {
    required AppLocalizations l10n,
  }) {
    final percentage = (value * 100).round();
    return l10n.percentValue(percentage);
  }
}
