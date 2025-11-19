import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/feature_flags/feature_flags_manager.dart';
import 'package:flutter_starter/features/feature_flags/presentation/providers/feature_flags_providers.dart';

/// Widget builder that conditionally renders content based on feature flags
///
/// Usage:
/// ```dart
/// FeatureFlagBuilder(
///   flag: FeatureFlags.newFeature,
///   enabledBuilder: (context) => NewFeatureWidget(),
///   disabledBuilder: (context) => OldFeatureWidget(),
/// )
/// ```
class FeatureFlagBuilder extends ConsumerWidget {
  /// Creates a [FeatureFlagBuilder] with the given [flag] and builders
  const FeatureFlagBuilder({
    required this.flag,
    required this.enabledBuilder,
    this.disabledBuilder,
    this.loadingBuilder,
    super.key,
  });

  /// The feature flag to check
  final FeatureFlagKey flag;

  /// Builder for when the flag is enabled
  final Widget Function(BuildContext context) enabledBuilder;

  /// Builder for when the flag is disabled (optional)
  final Widget Function(BuildContext context)? disabledBuilder;

  /// Builder for when the flag is loading (optional)
  final Widget Function(BuildContext context)? loadingBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flagAsync = ref.watch(isFeatureEnabledProvider(flag));

    return flagAsync.when(
      data: (isEnabled) {
        if (isEnabled) {
          return enabledBuilder(context);
        } else {
          return disabledBuilder?.call(context) ?? const SizedBox.shrink();
        }
      },
      loading: () =>
          loadingBuilder?.call(context) ??
          const Center(child: CircularProgressIndicator()),
      error: (error, stack) {
        // On error, default to disabled state
        return disabledBuilder?.call(context) ?? const SizedBox.shrink();
      },
    );
  }
}

/// Widget that shows content only when a feature flag is enabled
///
/// Usage:
/// ```dart
/// FeatureFlagWidget(
///   flag: FeatureFlags.newFeature,
///   child: NewFeatureWidget(),
/// )
/// ```
class FeatureFlagWidget extends ConsumerWidget {
  /// Creates a [FeatureFlagWidget] with the given [flag] and [child]
  const FeatureFlagWidget({
    required this.flag,
    required this.child,
    this.fallback,
    super.key,
  });

  /// The feature flag to check
  final FeatureFlagKey flag;

  /// Widget to show when flag is enabled
  final Widget child;

  /// Widget to show when flag is disabled (optional)
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FeatureFlagBuilder(
      flag: flag,
      enabledBuilder: (_) => child,
      disabledBuilder: (_) => fallback ?? const SizedBox.shrink(),
    );
  }
}
