import 'package:flutter/material.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/shared/accessibility/accessibility_widgets.dart';

/// Reusable error widget
///
/// Includes accessibility features such as proper semantic labels
/// and screen reader support.
class AppErrorWidget extends StatelessWidget {
  /// Creates an [AppErrorWidget] with the given [message] and optional
  /// [onRetry] callback
  const AppErrorWidget({
    required this.message,
    super.key,
    this.onRetry,
  });

  /// Error message to display
  final String message;

  /// Optional callback function called when retry button is pressed
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Semantics(
      label: 'Error: $message',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                label: 'Error icon',
                child: Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              AccessibleText(
                message,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 24),
                AccessibleButton(
                  label: l10n?.retry ?? 'Retry',
                  onPressed: onRetry,
                  icon: Icons.refresh,
                  semanticLabel: 'Retry, ${l10n?.retry ?? 'Retry'}',
                  semanticHint: 'Attempts to reload the content',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
