import 'package:flutter/material.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

/// Product 404 shown by the router's `errorBuilder` for an unmatched location.
///
/// Without an `errorBuilder`, go_router falls back to its own red debug page,
/// which prints the framework exception and stack trace at the user.
class RouteNotFoundScreen extends StatelessWidget {
  /// Creates the 404 screen for [location].
  const RouteNotFoundScreen({required this.location, super.key});

  /// The location that matched no route, shown verbatim so a bug report can
  /// name it.
  final String location;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pageNotFoundTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.explore_off_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  l10n.pageNotFoundTitle,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.pageNotFoundMessage,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                location,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(AppRoutes.home),
                child: Text(l10n.backToHome),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
