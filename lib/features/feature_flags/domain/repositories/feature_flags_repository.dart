import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/feature_flags/domain/entities/feature_flag.dart';

/// Feature flags repository interface (domain layer)
///
/// Provides methods to fetch and manage feature flags from various sources.
abstract class FeatureFlagsRepository {
  /// Get a feature flag by key
  ///
  /// Returns the feature flag value from the highest priority source.
  /// Priority order: local override > remote config > environment >
  /// compile-time
  Future<Result<FeatureFlag>> getFlag(String key);

  /// Get multiple feature flags by keys
  ///
  /// Returns a map of flag keys to their values.
  Future<Result<Map<String, FeatureFlag>>> getFlags(List<String> keys);

  /// Get all available feature flags
  Future<Result<Map<String, FeatureFlag>>> getAllFlags();

  /// Refresh remote feature flags
  ///
  /// Fetches the latest flags from Firebase Remote Config.
  Future<Result<void>> refreshRemoteFlags();

  /// Set a local override for a feature flag
  ///
  /// This allows overriding remote/environment flags for testing purposes.
  Future<Result<void>> setLocalOverride(String key, {required bool value});

  /// Clear a local override for a feature flag
  Future<Result<void>> clearLocalOverride(String key);

  /// Clear all local overrides
  Future<Result<void>> clearAllLocalOverrides();

  /// Check if a feature flag is enabled
  ///
  /// Convenience method that returns true if the flag exists and is enabled.
  Future<Result<bool>> isEnabled(String key);

  /// Initialize the feature flags system
  ///
  /// Should be called during app startup to load remote flags.
  Future<Result<void>> initialize();
}
