import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/feature_flags/feature_flags_manager.dart';
import 'package:flutter_starter/features/feature_flags/presentation/providers/feature_flags_providers.dart';
import 'package:flutter_starter/features/feature_flags/presentation/screens/feature_flags_debug_screen.dart';
import 'package:flutter_starter/features/feature_flags/presentation/widgets/feature_flag_builder.dart';

/// Example screen demonstrating feature flags usage
///
/// This screen shows various ways to use feature flags in your app.
class FeatureFlagsExampleScreen extends ConsumerWidget {
  /// Creates a [FeatureFlagsExampleScreen]
  const FeatureFlagsExampleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feature Flags Examples'),
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
              tooltip: 'Open Debug Menu',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            context,
            'Example 1: FeatureFlagBuilder',
            _buildExample1(),
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            'Example 2: FeatureFlagWidget',
            _buildExample2(),
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            'Example 3: Direct Provider Access',
            _buildExample3(ref),
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            'Example 4: Conditional Navigation',
            _buildExample4(ref),
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
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        content,
      ],
    );
  }

  /// Example 1: Using FeatureFlagBuilder with different builders
  Widget _buildExample1() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This example shows how to use FeatureFlagBuilder to '
              'conditionally render widgets.',
            ),
            const SizedBox(height: 16),
            FeatureFlagBuilder(
              flag: FeatureFlags.newFeature,
              enabledBuilder: (context) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('New Feature is ENABLED'),
                  ],
                ),
              ),
              disabledBuilder: (context) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.cancel, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('New Feature is DISABLED'),
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
  Widget _buildExample2() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This example shows how to use FeatureFlagWidget for simple show/hide scenarios.',
            ),
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
                child: const Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber),
                    SizedBox(width: 8),
                    Text('Premium Features Available'),
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
  Widget _buildExample3(WidgetRef ref) {
    final isEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlags.darkMode),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This example shows how to access feature flags directly from '
              'providers for complex logic.',
            ),
            const SizedBox(height: 16),
            isEnabled.when(
              data: (enabled) => SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: Text(
                  enabled
                      ? 'Dark mode is enabled'
                      : 'Dark mode is disabled',
                ),
                value: enabled,
                onChanged: (value) {
                  // In a real app, you'd update the theme here
                  ScaffoldMessenger.of(ref.context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Dark mode ${value ? "enabled" : "disabled"}',
                      ),
                    ),
                  );
                },
              ),
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text('Error: $error'),
            ),
          ],
        ),
      ),
    );
  }

  /// Example 4: Conditional navigation based on feature flags
  Widget _buildExample4(WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This example shows how to conditionally show navigation options '
              'based on feature flags.',
            ),
            const SizedBox(height: 16),
            FeatureFlagBuilder(
              flag: FeatureFlags.analytics,
              enabledBuilder: (context) => ElevatedButton.icon(
                onPressed: () {
                  // Navigate to analytics screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Navigating to Analytics...'),
                    ),
                  );
                },
                icon: const Icon(Icons.analytics),
                label: const Text('View Analytics'),
              ),
              disabledBuilder: (context) => OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('Analytics Unavailable'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
