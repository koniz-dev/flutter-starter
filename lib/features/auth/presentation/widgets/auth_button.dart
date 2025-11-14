import 'package:flutter/material.dart';

/// Reusable authentication button widget
class AuthButton extends StatelessWidget {
  /// Creates an [AuthButton] with the given [text], [onPressed] callback, and
  /// [isLoading] state
  const AuthButton({
    required this.text,
    super.key,
    this.onPressed,
    this.isLoading = false,
  });

  /// Button text label
  final String text;

  /// Callback function called when button is pressed
  final VoidCallback? onPressed;

  /// Whether the button is in loading state
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(text),
    );
  }
}
