import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/config/env_config.dart';
import 'package:flutter_starter/features/feature_flags/domain/entities/feature_flag.dart';

/// Service for managing local feature flags
///
/// Handles compile-time, environment-based, and build mode flags.
class LocalFeatureFlagsService {
  LocalFeatureFlagsService._();

  /// Singleton instance of [LocalFeatureFlagsService]
  static final LocalFeatureFlagsService instance = LocalFeatureFlagsService._();

  /// Get a feature flag value from local sources
  ///
  /// Priority order:
  /// 1. Environment variable (FEATURE_&lt;KEY&gt;)
  /// 2. Build mode (debug/release)
  /// 3. Compile-time constant
  ///
  /// Returns null if the flag is not found in local sources.
  FeatureFlag? getLocalFlag(
    String key, {
    bool? compileTimeDefault,
    bool? debugDefault,
    bool? releaseDefault,
    String? description,
  }) {
    // Priority 1: Environment variable
    final envKey = 'FEATURE_${key.toUpperCase()}';
    if (EnvConfig.has(envKey)) {
      return FeatureFlag(
        key: key,
        value: EnvConfig.getBool(envKey),
        source: FeatureFlagSource.environment,
        description: description,
        defaultValue: compileTimeDefault ?? debugDefault ?? releaseDefault,
      );
    }

    // Priority 2: Build mode based
    if (kDebugMode && debugDefault != null) {
      return FeatureFlag(
        key: key,
        value: debugDefault,
        source: FeatureFlagSource.buildMode,
        description: description,
        defaultValue: debugDefault,
      );
    }

    if (kReleaseMode && releaseDefault != null) {
      return FeatureFlag(
        key: key,
        value: releaseDefault,
        source: FeatureFlagSource.buildMode,
        description: description,
        defaultValue: releaseDefault,
      );
    }

    // Priority 3: Compile-time constant
    if (compileTimeDefault != null) {
      return FeatureFlag(
        key: key,
        value: compileTimeDefault,
        source: FeatureFlagSource.compileTime,
        description: description,
        defaultValue: compileTimeDefault,
      );
    }

    return null;
  }

  /// Get all local feature flags
  ///
  /// Returns a map of all flags defined locally.
  Map<String, FeatureFlag> getAllLocalFlags() {
    final flags = <String, FeatureFlag>{};

    // Add flags from local definitions
    // You can extend this to read from a configuration file
    for (final flagDef in _localFlagDefinitions) {
      final flag = getLocalFlag(
        flagDef.key,
        compileTimeDefault: flagDef.compileTimeDefault,
        debugDefault: flagDef.debugDefault,
        releaseDefault: flagDef.releaseDefault,
        description: flagDef.description,
      );
      if (flag != null) {
        flags[flag.key] = flag;
      }
    }

    return flags;
  }

  /// Local flag definitions
  ///
  /// Define your local feature flags here. These are compile-time or
  /// environment-based flags that don't require remote configuration.
  static final List<LocalFlagDefinition> _localFlagDefinitions = [
    // Example: A feature that's only enabled in debug mode
    const LocalFlagDefinition(
      key: 'enable_debug_menu',
      compileTimeDefault: false,
      debugDefault: true,
      releaseDefault: false,
      description: 'Enable debug menu for development',
    ),
    // Example: A feature controlled by environment variable
    const LocalFlagDefinition(
      key: 'enable_experimental_features',
      compileTimeDefault: false,
      description:
          'Enable experimental features '
          '(set via FEATURE_ENABLE_EXPERIMENTAL_FEATURES)',
    ),
  ];
}

/// Definition for a local feature flag
class LocalFlagDefinition {
  /// Creates a [LocalFlagDefinition] with the given properties
  const LocalFlagDefinition({
    required this.key,
    this.compileTimeDefault,
    this.debugDefault,
    this.releaseDefault,
    this.description,
  });

  /// The flag key
  final String key;

  /// Compile-time default value
  final bool? compileTimeDefault;

  /// Debug mode default value
  final bool? debugDefault;

  /// Release mode default value
  final bool? releaseDefault;

  /// Description of the flag
  final String? description;
}
