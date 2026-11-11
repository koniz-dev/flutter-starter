import 'package:flutter/material.dart';
import 'package:flutter_starter/shared/design_system/tokens/app_colors.dart';

/// BuildContext extension methods
///
/// This extension provides convenient methods for common BuildContext
/// operations: theming, screen-size queries, and UI feedback.
///
/// **Navigation is deliberately absent.** This app routes with `go_router`, so
/// navigation lives in `lib/core/routing/`, not here. Beyond being a second
/// answer to the same question, a `pop` member on this extension would share
/// both its name and its receiver with `go_router`'s `GoRouterHelper.pop`,
/// making `context.pop()` an `ambiguous_extension_member_access` error in any
/// file that imports both.
///
/// **Usage:**
/// ```dart
/// context.showSnackBar('Operation successful');
/// ```
extension ContextExtensions on BuildContext {
  /// Get theme
  ThemeData get theme => Theme.of(this);

  /// Get text theme
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Get color scheme
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Get media query
  MediaQueryData get mediaQuery => MediaQuery.of(this);

  /// Get screen size
  Size get screenSize => mediaQuery.size;

  /// Get screen width
  double get screenWidth => screenSize.width;

  /// Get screen height
  double get screenHeight => screenSize.height;

  /// Check if screen is mobile (< 600px)
  bool get isMobile => screenWidth < 600;

  /// Check if screen is tablet (600px - 1024px)
  bool get isTablet => screenWidth >= 600 && screenWidth < 1024;

  /// Check if screen is desktop (>= 1024px)
  bool get isDesktop => screenWidth >= 1024;

  /// Show snackbar
  void showSnackBar(String message, {Duration? duration}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }

  /// Show error snackbar
  void showErrorSnackBar(String message, {Duration? duration}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: colorScheme.error,
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }

  /// Show success snackbar
  void showSuccessSnackBar(String message, {Duration? duration}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }
}
