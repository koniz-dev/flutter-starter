/// Accessibility constants and guidelines
///
/// These constants follow WCAG 2.1 guidelines and Flutter best practices
/// for accessibility.
///
/// Every constant here is **enforced** by code in this repository:
/// [minTouchTargetSize] by `AccessibilityHelpers.ensureMinTouchTarget` and the
/// contrast ratios by the `meetsContrastRatio*` checks. Constants that merely
/// described a guarantee nothing implemented (a focus-announcement debounce, a
/// minimum readable font size, recommended font sizes, a decorative-icon label
/// and a touch-target spacing) were removed rather than left to read as
/// promises - see koniz-dev/flutter-starter#65.
class AccessibilityConstants {
  AccessibilityConstants._();

  /// Minimum touch target size (48x48 logical pixels)
  ///
  /// WCAG 2.1 Level AAA recommends at least 44x44 CSS pixels.
  /// Flutter uses logical pixels, so 48x48 ensures good touch accessibility.
  static const double minTouchTargetSize = 48;

  /// Minimum contrast ratio for normal text (4.5:1)
  ///
  /// WCAG 2.1 Level AA requirement for normal text
  /// (less than 18pt or 14pt bold).
  static const double minContrastRatioNormal = 4.5;

  /// Minimum contrast ratio for large text (3:1)
  ///
  /// WCAG 2.1 Level AA requirement for large text (18pt+ or 14pt+ bold).
  static const double minContrastRatioLarge = 3;

  /// Minimum contrast ratio for enhanced contrast (7:1)
  ///
  /// WCAG 2.1 Level AAA requirement for normal text.
  static const double minContrastRatioEnhanced = 7;
}
