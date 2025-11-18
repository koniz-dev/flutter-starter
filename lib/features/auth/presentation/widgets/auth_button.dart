import 'package:flutter/material.dart';

import 'package:flutter_starter/shared/accessibility/accessibility_widgets.dart';

/// Reusable authentication button widget
///
/// Includes accessibility features such as proper semantic labels,
/// minimum touch target size, and screen reader support.
class AuthButton extends StatelessWidget {
  /// Creates an [AuthButton] with the given [text], [onPressed] callback, and
  /// [isLoading] state
  const AuthButton({
    required this.text,
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.semanticLabel,
    this.semanticHint,
  });

  /// Button text label
  final String text;

  /// Callback function called when button is pressed
  final VoidCallback? onPressed;

  /// Whether the button is in loading state
  final bool isLoading;

  /// Custom semantic label for screen readers
  ///
  /// If not provided, uses [text] with state information.
  final String? semanticLabel;

  /// Semantic hint for screen readers
  ///
  /// Provides additional context about what the button does.
  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    return AccessibleButton(
      label: text,
      onPressed: onPressed,
      isLoading: isLoading,
      isEnabled: onPressed != null && !isLoading,
      semanticLabel: semanticLabel,
      semanticHint: semanticHint,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
      ),
    );
  }
}
