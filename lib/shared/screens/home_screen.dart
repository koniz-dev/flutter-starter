import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/routing/navigation_extensions.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/shared/widgets/language_switcher.dart';

/// Home screen widget
class HomeScreen extends ConsumerWidget {
  /// Creates a [HomeScreen] widget
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          // Language switcher
          const LanguageSwitcher(),
          // Show debug menu button if debug features are enabled
          if (AppConfig.enableDebugFeatures)
            Semantics(
              label: l10n.featureFlagsDebug,
              hint: 'Opens feature flags debug screen',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.bug_report),
                onPressed: () {
                  context.goToFeatureFlagsDebug();
                },
                tooltip: l10n.featureFlagsDebug,
              ),
            ),
        ],
      ),
      body: RepaintBoundary(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.welcome,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(
                  l10n.featureFlagsReady,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.checkExamples,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
