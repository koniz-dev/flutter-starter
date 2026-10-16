import 'package:flutter/foundation.dart';
import 'package:flutter_starter/features/feature_flags/domain/entities/feature_flag.dart';

/// Service for managing local feature flags
///
/// Handles compile-time and build-mode flags. A remote source and the debug
/// screen's local overrides sit above these; see the feature-flags guide.
///
/// There is deliberately **no environment level** (koniz-dev/flutter-starter#279).
/// It used to come first, reading `EnvConfig.has('FEATURE_<KEY>')`, but
/// `EnvConfig` reads a `--dart-define` only through the const `DartDefines`
/// table (#48), and a key built at run time from the flag name is never in
/// that table. So `--dart-define=FEATURE_...=true` was discarded in every
/// build, and the level could fire only from a `.env` bundled as an asset,
/// which `docs/guides/configuration.md` tells you not to ship. A promise the
/// code cannot keep was removed rather than kept.
///
/// To flip a local flag per build, give its definition a literal
/// `bool.fromEnvironment('FEATURE_<KEY>')` default, which every compiler
/// resolves, or use the remote source.
class LocalFeatureFlagsService {
  LocalFeatureFlagsService._();

  /// Singleton instance of [LocalFeatureFlagsService]
  static final LocalFeatureFlagsService instance = LocalFeatureFlagsService._();

  /// Get a feature flag value from local sources
  ///
  /// Priority order:
  /// 1. Build mode (debug/release)
  /// 2. Compile-time constant
  ///
  /// Returns null if the flag is not found in local sources.
  FeatureFlag? getLocalFlag(
    String key, {
    bool? compileTimeDefault,
    bool? debugDefault,
    bool? releaseDefault,
    String? description,
  }) {
    // Priority 1: Build mode based
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

    // Priority 2: Compile-time constant
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
  /// build-mode flags that don't require remote configuration.
  static final List<LocalFlagDefinition> _localFlagDefinitions = [
    // Example: A feature that's only enabled in debug mode
    const LocalFlagDefinition(
      key: 'enable_debug_menu',
      compileTimeDefault: false,
      debugDefault: true,
      releaseDefault: false,
      description: 'Enable debug menu for development',
    ),
    // Example: A feature that is off unless the remote source or a local
    // override turns it on
    const LocalFlagDefinition(
      key: 'enable_experimental_features',
      compileTimeDefault: false,
      description: 'Enable experimental features',
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
