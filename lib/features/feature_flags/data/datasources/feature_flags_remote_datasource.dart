/// Remote data source for feature flags.
///
/// **No remote implementation ships with this starter.** The provider binds
/// [NoOpFeatureFlagsRemoteDataSource], so flags resolve from the local source
/// alone and the app takes on no flag vendor by default.
///
/// To add one, implement this contract and override
/// `featureFlagsRemoteDataSourceProvider`, generated from the
/// `@riverpod featureFlagsRemoteDataSource` function in
/// `feature_flags_providers.dart` under this feature's
/// `presentation/providers/`. Firebase Remote Config, LaunchDarkly, Unleash
/// or a JSON endpoint of your own all sit behind it equally well: no method
/// below mentions a vendor, and that is the point of the five of them being
/// this plain.
///
/// This comment used to send the reader to a template file in this directory.
/// None was ever committed - not here, and not anywhere in the history
/// (koniz-dev/flutter-starter#207). Writing one now would ship vendor code
/// that `flutter analyze` never reads, to save implementing a contract that
/// is legible from its own signature.
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
