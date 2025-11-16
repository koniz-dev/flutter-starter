import 'package:flutter/foundation.dart';

/// Feature flag entity (domain layer)
///
/// Represents a feature flag with its key, value, source, and metadata.
@immutable
class FeatureFlag {
  /// Creates a [FeatureFlag] with the given properties
  const FeatureFlag({
    required this.key,
    required this.value,
    required this.source,
    this.description,
    this.defaultValue,
    this.lastUpdated,
  });

  /// Unique identifier for the feature flag
  final String key;

  /// Current value of the feature flag
  final bool value;

  /// Source of the feature flag value
  final FeatureFlagSource source;

  /// Optional description of what this flag controls
  final String? description;

  /// Default value for this flag
  final bool? defaultValue;

  /// Timestamp when the flag was last updated
  final DateTime? lastUpdated;

  /// Creates a copy of this feature flag with updated values
  FeatureFlag copyWith({
    String? key,
    bool? value,
    FeatureFlagSource? source,
    String? description,
    bool? defaultValue,
    DateTime? lastUpdated,
  }) {
    return FeatureFlag(
      key: key ?? this.key,
      value: value ?? this.value,
      source: source ?? this.source,
      description: description ?? this.description,
      defaultValue: defaultValue ?? this.defaultValue,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeatureFlag &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          value == other.value &&
          source == other.source;

  @override
  int get hashCode => key.hashCode ^ value.hashCode ^ source.hashCode;

  @override
  String toString() {
    return 'FeatureFlag(key: $key, value: $value, source: $source)';
  }
}

/// Source of a feature flag value
enum FeatureFlagSource {
  /// Compile-time constant (const bool)
  compileTime,

  /// Environment variable (.env or --dart-define)
  environment,

  /// Debug/Release mode based
  buildMode,

  /// Firebase Remote Config
  remoteConfig,

  /// Local override (from debug menu or local storage)
  localOverride,
}
