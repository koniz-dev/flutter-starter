import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/constants/ui_keys.dart';
import 'package:flutter_starter/core/routing/app_routes.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';
import 'package:flutter_starter/shared/widgets/language_switcher.dart';
import 'package:go_router/go_router.dart';

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
          const LanguageSwitcher(),
          if (AppConfig.enableDebugFeatures)
            Semantics(
              label: l10n.featureFlagsDebug,
              hint: 'Opens feature flags debug screen',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.bug_report),
                onPressed: () => context.go(AppRoutes.featureFlagsDebug),
                tooltip: l10n.featureFlagsDebug,
              ),
            ),
        ],
      ),
      body: RepaintBoundary(
        key: UiKeys.homeContent,
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
              Text(l10n.checkExamples, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
