import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/feature_flags/feature_flags_manager.dart';
import 'package:flutter_starter/features/feature_flags/domain/entities/feature_flag.dart';
import 'package:flutter_starter/features/feature_flags/presentation/providers/feature_flags_providers.dart';

/// Debug screen for managing feature flags
///
/// Allows developers to view and toggle feature flags during development.
class FeatureFlagsDebugScreen extends ConsumerStatefulWidget {
  /// Creates a [FeatureFlagsDebugScreen]
  const FeatureFlagsDebugScreen({super.key});

  @override
  ConsumerState<FeatureFlagsDebugScreen> createState() =>
      _FeatureFlagsDebugScreenState();
}

class _FeatureFlagsDebugScreenState
    extends ConsumerState<FeatureFlagsDebugScreen> {
  @override
  Widget build(BuildContext context) {
    final allFlagsAsync = ref.watch(allFeatureFlagsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feature Flags Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              ref.invalidate(allFeatureFlagsProvider);
              await ref.read(featureFlagsManagerProvider).refresh();
            },
            tooltip: 'Refresh flags',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () async {
              if (!mounted) return;
              final navigatorContext = context;
              final messenger = ScaffoldMessenger.of(context);
              final confirmed = await showDialog<bool>(
                context: navigatorContext,
                builder: (context) => AlertDialog(
                  title: const Text('Clear All Overrides'),
                  content: const Text(
                    'Are you sure you want to clear all local overrides?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );

              if (confirmed ?? false) {
                await ref
                    .read(featureFlagsManagerProvider)
                    .clearAllLocalOverrides();
                ref.invalidate(allFeatureFlagsProvider);
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('All local overrides cleared'),
                  ),
                );
              }
            },
            tooltip: 'Clear all overrides',
          ),
        ],
      ),
      body: allFlagsAsync.when(
        data: _buildFlagsList,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(allFeatureFlagsProvider);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlagsList(Map<String, FeatureFlag?> flags) {
    if (flags.isEmpty) {
      return const Center(
        child: Text('No feature flags found'),
      );
    }

    // Group flags by category
    final categorizedFlags = <String, List<FeatureFlag>>{};
    final uncategorizedFlags = <FeatureFlag>[];

    for (final flag in flags.values) {
      if (flag == null) continue;

      // Try to find category from FeatureFlags definitions
      final flagKey =
          FeatureFlags.all
              .where((FeatureFlagKey key) => key.value == flag.key)
              .firstOrNull ??
          FeatureFlagKey(
            value: flag.key,
            defaultValue: false,
            description: flag.description ?? 'No description',
          );

      if (flagKey.category != null && flagKey.category!.isNotEmpty) {
        categorizedFlags.putIfAbsent(flagKey.category!, () => []).add(flag);
      } else {
        uncategorizedFlags.add(flag);
      }
    }

    return ListView(
      children: [
        // Show categorized flags
        ...categorizedFlags.entries.map(
          (entry) => _buildCategorySection(entry.key, entry.value),
        ),
        // Show uncategorized flags
        if (uncategorizedFlags.isNotEmpty)
          _buildCategorySection('Other', uncategorizedFlags),
      ],
    );
  }

  Widget _buildCategorySection(String category, List<FeatureFlag> flags) {
    return ExpansionTile(
      title: Text(
        category,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      children: flags.map(_buildFlagTile).toList(),
    );
  }

  Widget _buildFlagTile(FeatureFlag flag) {
    final flagKey =
        FeatureFlags.all
            .where((FeatureFlagKey key) => key.value == flag.key)
            .firstOrNull ??
        FeatureFlagKey(
          value: flag.key,
          defaultValue: false,
          description: flag.description ?? 'No description',
        );

    return ListTile(
      title: Text(flag.key),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (flagKey.description.isNotEmpty)
            Text(
              flagKey.description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              _buildSourceChip(flag.source),
              const SizedBox(width: 8),
              if (flag.lastUpdated != null)
                Text(
                  'Updated: ${_formatDate(flag.lastUpdated!)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
            ],
          ),
        ],
      ),
      trailing: Switch(
        value: flag.value,
        onChanged: (value) async {
          await ref
              .read(featureFlagsManagerProvider)
              .setLocalOverride(flagKey, value: value);
          ref.invalidate(allFeatureFlagsProvider);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${flag.key} ${value ? "enabled" : "disabled"}',
              ),
              duration: const Duration(seconds: 1),
            ),
          );
        },
      ),
      onLongPress: () async {
        // Long press to clear override
        await ref.read(featureFlagsManagerProvider).clearLocalOverride(flagKey);
        ref.invalidate(allFeatureFlagsProvider);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Override cleared for ${flag.key}'),
          ),
        );
      },
    );
  }

  Widget _buildSourceChip(FeatureFlagSource source) {
    final color = switch (source) {
      FeatureFlagSource.localOverride => Colors.orange,
      FeatureFlagSource.remoteConfig => Colors.blue,
      FeatureFlagSource.environment => Colors.green,
      FeatureFlagSource.buildMode => Colors.purple,
      FeatureFlagSource.compileTime => Colors.grey,
    };

    return Chip(
      label: Text(
        source.name.toUpperCase(),
        style: const TextStyle(fontSize: 10),
      ),
      backgroundColor: color.withValues(alpha: 0.2),
      labelStyle: TextStyle(color: color),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}
