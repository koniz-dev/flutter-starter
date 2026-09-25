import 'package:flutter/material.dart';
import 'package:flutter_starter/shared/design_system/tokens/app_colors.dart';

/// Semantic typography tokens for the Design System.
///
/// Avoid arbitrary font sizes in UI code.
/// Use these predefined styles in a Text widget or via Theme.of(context).
///
/// ## Typeface: deliberately unset
///
/// None of the styles below declares a `fontFamily`. That is on purpose: this
/// starter vendors no font file, so naming a family here would name one that
/// is not bundled, and Flutter resolves an unknown family by falling back
/// silently.
///
/// A null `fontFamily` also survives the `defaultTextTheme.merge(textTheme)`
/// the `ThemeData` constructor performs, so what actually renders is the
/// per-platform family `Typography` already picks: Roboto on Android and
/// Fuchsia, `CupertinoSystemDisplay`/`CupertinoSystemText` on iOS,
/// `.AppleSystemUIFont` on macOS, `Segoe UI` on Windows, and Roboto with a
/// Ubuntu/Cantarell/DejaVu fallback chain on Linux. On web the CanvasKit and
/// skwasm renderers register Roboto as their own default family. Setting a
/// family here overrides all of that with one name for every target.
///
/// `test/shared/theme/app_theme_font_family_test.dart` pins that behaviour per
/// `TargetPlatform`.
///
/// To adopt a specific typeface instead:
///
/// 1. Vendor the font under `assets/fonts/` and declare it in the `fonts:`
///    section of `pubspec.yaml` - that section is commented out by default and
///    is separate from `assets:`, so adding the directory to `assets:` is not
///    enough. Ship the font's licence alongside it.
/// 2. Apply it once for the whole app with `ThemeData(fontFamily: ...)` in
///    `lib/shared/theme/app_theme.dart`, or per style by adding `fontFamily:`
///    to the tokens below.
abstract class AppTypography {
  /// Large display text style
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  /// Medium headline text style
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Medium title text style
  static const TextStyle titleMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  /// Large body text style
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  /// Medium body text style
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  /// Text style for buttons and labels
  static const TextStyle labelButton = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
}
