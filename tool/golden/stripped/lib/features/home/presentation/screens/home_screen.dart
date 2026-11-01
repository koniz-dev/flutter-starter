import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_starter/core/constants/ui_keys.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/routing/navigation_extensions.dart';
import 'package:flutter_starter/core/routing/routes_registry.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/shared/widgets/language_switcher.dart';

/// Home screen after sign-in (minimal shell; extend per product).
///
/// Links to every screen a registered feature lists in
/// `homeDestinationsProvider`, and signs out from the app bar.
class HomeScreen extends ConsumerWidget {
  /// Creates the home screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final destinations = ref.watch(homeDestinationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          const LanguageSwitcher(),
          IconButton(
            key: UiKeys.homeSignOut,
            icon: const Icon(Icons.logout),
            tooltip: l10n.signOut,
            // The router redirects to sign-in once the session is gone.
            onPressed: () => ref.read(signOutProvider)(),
          ),
        ],
      ),
      body: RepaintBoundary(
        key: UiKeys.homeContent,
        child: Center(
          // Scrolls rather than overflows at large text scales.
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.welcome,
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.homeAddScreensHint,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (destinations.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final destination in destinations)
                          FilledButton.tonalIcon(
                            key: UiKeys.homeDestination(destination.id),
                            onPressed: () =>
                                context.pushRoute(destination.location),
                            icon: Icon(destination.icon),
                            label: Text(destination.label(l10n)),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
