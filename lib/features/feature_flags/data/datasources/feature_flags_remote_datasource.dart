/// Remote data source for feature flags.
///
/// The default starter does **not** depend on Firebase. If you want a Firebase
/// Remote Config implementation, use the `.template` file under
/// `lib/features/feature_flags/data/datasources/`.
abstract class FeatureFlagsRemoteDataSource {
  /// Initialize the remote config
  Future<void> initialize();

  /// Fetch and activate remote config values
  Future<void> fetchAndActivate();

  /// Get a feature flag value from remote config
  Future<bool?> getRemoteFlag(String key);

  /// Get all feature flags from remote config
  Future<Map<String, bool>> getAllRemoteFlags();

  /// Set default values for remote config
  Future<void> setDefaults(Map<String, dynamic> defaults);
}

/// Default implementation: no remote source (local-only).
final class NoOpFeatureFlagsRemoteDataSource
    implements FeatureFlagsRemoteDataSource {
  /// Creates an empty remote layer (local-only flags still work).
  const NoOpFeatureFlagsRemoteDataSource();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> fetchAndActivate() async {}

  @override
  Future<bool?> getRemoteFlag(String key) async => null;

  @override
  Future<Map<String, bool>> getAllRemoteFlags() async => const {};

  @override
  Future<void> setDefaults(Map<String, dynamic> defaults) async {}
}
