import 'package:flutter/material.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';

/// Reusable error widget
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l10n?.retry ?? 'Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
