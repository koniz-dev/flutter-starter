import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/feature_flags/domain/entities/feature_flag.dart';
import 'package:flutter_starter/features/feature_flags/domain/repositories/feature_flags_repository.dart';

/// Centralized feature flags manager
///
/// Provides type-safe access to feature flags with centralized definitions
/// and documentation.
///
/// Usage:
/// ```dart
/// final flagsManager = FeatureFlagsManager(repository);
/// if (await flagsManager.isEnabled(FeatureFlags.newFeature)) {
///   // Show new feature
/// }
/// ```
class FeatureFlagsManager {
  /// Creates a [FeatureFlagsManager] with the given [_repository]
  FeatureFlagsManager(this._repository);

  final FeatureFlagsRepository _repository;

  /// Get a feature flag value
  ///
  /// Returns the flag value from the highest priority source.
  Future<bool> isEnabled(FeatureFlagKey key) async {
    final result = await _repository.getFlag(key.value);
    return result.when(
      success: (FeatureFlag flag) => flag.value,
      failureCallback: (Failure _) => key.defaultValue,
    );
  }

  /// Get a feature flag with full details
  Future<FeatureFlag?> getFlag(FeatureFlagKey key) async {
    final result = await _repository.getFlag(key.value);
    return result.when(
      success: (FeatureFlag flag) => flag,
      failureCallback: (Failure _) => null,
    );
  }

  /// Get multiple feature flags
  Future<Map<String, bool>> getFlags(List<FeatureFlagKey> keys) async {
    final flagKeys = keys.map((FeatureFlagKey k) => k.value).toList();
    final result = await _repository.getFlags(flagKeys);
    return result.when(
      success: (Map<String, FeatureFlag> flags) =>
          flags.map((String k, FeatureFlag v) => MapEntry(k, v.value)),
      failureCallback: (Failure _) => <String, bool>{},
    );
  }

  /// Refresh remote feature flags
  Future<void> refresh() async {
    await _repository.refreshRemoteFlags();
  }

  /// Set a local override for a feature flag
  Future<void> setLocalOverride(
    FeatureFlagKey key, {
    required bool value,
  }) async {
    await _repository.setLocalOverride(key.value, value: value);
  }

  /// Clear a local override for a feature flag
  Future<void> clearLocalOverride(FeatureFlagKey key) async {
    await _repository.clearLocalOverride(key.value);
  }

  /// Clear all local overrides
  Future<void> clearAllLocalOverrides() async {
    await _repository.clearAllLocalOverrides();
  }
}

/// Feature flag key definition
///
/// Each feature flag should have a corresponding [FeatureFlagKey] instance
/// that defines its key, default value, and documentation.
@immutable
class FeatureFlagKey {
  /// Creates a [FeatureFlagKey] with the given properties
  const FeatureFlagKey({
    required this.value,
    required this.defaultValue,
    required this.description,
    this.category,
  });

  /// The flag key (e.g., 'enable_new_feature')
  final String value;

  /// Default value if flag is not found
  final bool defaultValue;

  /// Description of what this flag controls
  final String description;

  /// Optional category for grouping flags
  final String? category;

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeatureFlagKey &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Centralized feature flag definitions
///
/// All feature flags should be defined here for type-safe access.
class FeatureFlags {
  FeatureFlags._();

  // Example feature flags - replace with your actual flags

  /// Enable new experimental feature
  static const FeatureFlagKey newFeature = FeatureFlagKey(
    value: 'enable_new_feature',
    defaultValue: false,
    description: 'Enable the new experimental feature',
    category: 'Features',
  );

  /// Enable premium features
  static const FeatureFlagKey premiumFeatures = FeatureFlagKey(
    value: 'enable_premium_features',
    defaultValue: false,
    description: 'Enable premium subscription features',
    category: 'Features',
  );

  /// Enable dark mode
  static const FeatureFlagKey darkMode = FeatureFlagKey(
    value: 'enable_dark_mode',
    defaultValue: true,
    description: 'Enable dark mode theme',
    category: 'UI',
  );

  /// Enable analytics tracking
  static const FeatureFlagKey analytics = FeatureFlagKey(
    value: 'enable_analytics',
    defaultValue: true,
    description: 'Enable analytics tracking',
    category: 'Analytics',
  );

  /// Enable A/B testing
  static const FeatureFlagKey abTesting = FeatureFlagKey(
    value: 'enable_ab_testing',
    defaultValue: false,
    description: 'Enable A/B testing features',
    category: 'Testing',
  );

  /// Enable debug menu
  static const FeatureFlagKey debugMenu = FeatureFlagKey(
    value: 'enable_debug_menu',
    defaultValue: false,
    description: 'Enable debug menu for development',
    category: 'Debug',
  );

  /// Enable push notifications
  static const FeatureFlagKey pushNotifications = FeatureFlagKey(
    value: 'enable_push_notifications',
    defaultValue: true,
    description: 'Enable push notifications',
    category: 'Notifications',
  );

  /// Enable tasks feature
  static const FeatureFlagKey tasks = FeatureFlagKey(
    value: 'enable_tasks',
    defaultValue: true,
    description: 'Enable tasks management feature',
    category: 'Features',
  );

  /// Get all defined feature flags
  static List<FeatureFlagKey> get all => [
        newFeature,
        premiumFeatures,
        darkMode,
        analytics,
        abTesting,
        debugMenu,
        pushNotifications,
        tasks,
      ];

  /// Get feature flags by category
  static List<FeatureFlagKey> getByCategory(String category) {
    return all.where((flag) => flag.category == category).toList();
  }
}
