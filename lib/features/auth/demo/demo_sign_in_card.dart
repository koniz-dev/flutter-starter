import 'package:flutter/material.dart';
import 'package:flutter_starter/core/constants/ui_keys.dart';
import 'package:flutter_starter/features/auth/demo/demo_auth.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';

/// Tells the user the app is signing in offline and offers the demo account.
///
/// Shown on the login screen only while [DemoAuth.enabled] is true.
class DemoSignInCard extends StatelessWidget {
  /// Creates the card; [onFill] puts the demo account into the form.
  const DemoSignInCard({required this.onFill, super.key});

  /// Called by the fill button.
  final VoidCallback onFill;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.science_outlined,
                  color: colors.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.demoModeTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.onSecondaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.demoModeBody(DemoAuth.email, DemoAuth.password),
              style: TextStyle(color: colors.onSecondaryContainer),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: OutlinedButton(
                key: UiKeys.demoSignInFill,
                onPressed: onFill,
                child: Text(l10n.demoModeFill),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
