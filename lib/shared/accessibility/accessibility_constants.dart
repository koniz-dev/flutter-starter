/// Accessibility constants and guidelines
///
/// These constants follow WCAG 2.1 guidelines and Flutter best practices
/// for accessibility.
class AccessibilityConstants {
  AccessibilityConstants._();

  /// Minimum touch target size (48x48 logical pixels)
  ///
  /// WCAG 2.1 Level AAA recommends at least 44x44 CSS pixels.
  /// Flutter uses logical pixels, so 48x48 ensures good touch accessibility.
  static const double minTouchTargetSize = 48;

  /// Minimum spacing between touch targets (8 logical pixels)
  ///
  /// Prevents accidental taps on adjacent interactive elements.
  static const double minTouchTargetSpacing = 8;

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

  /// Default semantic label for decorative icons
  ///
  /// Use this when an icon is purely decorative and doesn't convey meaning.
  static const String decorativeIconLabel = '';

  /// Default timeout for focus announcements (milliseconds)
  ///
  /// Time to wait before announcing focus changes to screen readers.
  static const int focusAnnouncementDelay = 100;

  /// Minimum font size for readable text (12sp)
  ///
  /// Ensures text is readable without zooming.
  static const double minReadableFontSize = 12;

  /// Recommended font size for body text (14sp)
  static const double recommendedBodyFontSize = 14;

  /// Recommended font size for large text (18sp)
  static const double recommendedLargeFontSize = 18;
}
