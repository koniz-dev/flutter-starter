import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/feature_flags/feature_flags_manager.dart';
import 'package:flutter_starter/core/localization/localization_extensions.dart';
import 'package:flutter_starter/features/feature_flags/presentation/providers/feature_flags_providers.dart';
import 'package:flutter_starter/features/feature_flags/presentation/screens/feature_flags_debug_screen.dart';
import 'package:flutter_starter/features/feature_flags/presentation/widgets/feature_flag_builder.dart';
import 'package:flutter_starter/l10n/app_localizations.dart';

/// Example screen demonstrating feature flags usage
///
/// This screen shows various ways to use feature flags in your app.
class FeatureFlagsExampleScreen extends ConsumerWidget {
  /// Creates a [FeatureFlagsExampleScreen]
  const FeatureFlagsExampleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.featureFlagsExamplesTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const FeatureFlagsDebugScreen(),
                ),
              );
            },
            tooltip: l10n.featureFlagsOpenDebugMenu,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            context,
            l10n.featureFlagsExample1Title,
            _buildExample1(l10n),
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            l10n.featureFlagsExample2Title,
            _buildExample2(l10n),
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            l10n.featureFlagsExample3Title,
            _buildExample3(ref, l10n),
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            l10n.featureFlagsExample4Title,
            _buildExample4(ref, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        content,
      ],
    );
  }

  /// Example 1: Using FeatureFlagBuilder with different builders
  Widget _buildExample1(AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.featureFlagsExample1Body),
            const SizedBox(height: 16),
            FeatureFlagBuilder(
              flag: FeatureFlags.newFeature,
              enabledBuilder: (context) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(l10n.featureFlagsNewFeatureEnabled),
                  ],
                ),
              ),
              disabledBuilder: (context) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cancel, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(l10n.featureFlagsNewFeatureDisabled),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Example 2: Using FeatureFlagWidget (simpler API)
  Widget _buildExample2(AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.featureFlagsExample2Body),
            const SizedBox(height: 16),
            FeatureFlagWidget(
              flag: FeatureFlags.premiumFeatures,
              fallback: const SizedBox.shrink(),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(l10n.featureFlagsPremiumAvailable),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Example 3: Direct provider access for complex logic
  Widget _buildExample3(WidgetRef ref, AppLocalizations l10n) {
    final isEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlags.darkMode),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.featureFlagsExample3Body),
            const SizedBox(height: 16),
            isEnabled.when(
              data: (enabled) => SwitchListTile(
                title: Text(l10n.featureFlagsDarkMode),
                subtitle: Text(
                  enabled
                      ? l10n.featureFlagsDarkModeIsEnabled
                      : l10n.featureFlagsDarkModeIsDisabled,
                ),
                value: enabled,
                onChanged: (value) {
                  // In a real app, you'd update the theme here
                  ScaffoldMessenger.of(ref.context).showSnackBar(
                    SnackBar(
                      content: Text(
                        value
                            ? l10n.featureFlagsDarkModeEnabled
                            : l10n.featureFlagsDarkModeDisabled,
                      ),
                    ),
                  );
                },
              ),
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) =>
                  Text(l10n.featureFlagsErrorMessage(error.toString())),
            ),
          ],
        ),
      ),
    );
  }

  /// Example 4: Conditional navigation based on feature flags
  Widget _buildExample4(WidgetRef ref, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.featureFlagsExample4Body),
            const SizedBox(height: 16),
            FeatureFlagBuilder(
              flag: FeatureFlags.analytics,
              enabledBuilder: (context) => ElevatedButton.icon(
                onPressed: () {
                  // Navigate to analytics screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.featureFlagsNavigatingToAnalytics),
                    ),
                  );
                },
                icon: const Icon(Icons.analytics),
                label: Text(l10n.featureFlagsViewAnalytics),
              ),
              disabledBuilder: (context) => OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.analytics_outlined),
                label: Text(l10n.featureFlagsAnalyticsUnavailable),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
