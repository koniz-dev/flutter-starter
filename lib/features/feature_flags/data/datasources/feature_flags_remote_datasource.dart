import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Remote data source for feature flags
///
/// Handles fetching feature flags from Firebase Remote Config.
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

/// Implementation of [FeatureFlagsRemoteDataSource] using Firebase Remote
/// Config
class FeatureFlagsRemoteDataSourceImpl implements FeatureFlagsRemoteDataSource {
  /// Creates a [FeatureFlagsRemoteDataSourceImpl] with optional
  /// [defaultValues]
  FeatureFlagsRemoteDataSourceImpl({
    Map<String, dynamic>? defaultValues,
  }) : _defaultValues = defaultValues ?? {};

  final Map<String, dynamic> _defaultValues;
  FirebaseRemoteConfig? _remoteConfig;
  bool _isInitialized = false;

  /// Get the Firebase Remote Config instance
  FirebaseRemoteConfig get remoteConfig {
    if (_remoteConfig == null) {
      throw StateError(
        'Remote Config not initialized. Call initialize() first.',
      );
    }
    return _remoteConfig!;
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    try {
      _remoteConfig = FirebaseRemoteConfig.instance;

      // Set default values
      if (_defaultValues.isNotEmpty) {
        await _remoteConfig!.setConfigSettings(
          RemoteConfigSettings(
            fetchTimeout: const Duration(seconds: 10),
            minimumFetchInterval: const Duration(hours: 1),
          ),
        );
        await _remoteConfig!.setDefaults(_defaultValues);
      }

      _isInitialized = true;
    } on Exception {
      // If Firebase is not initialized, we'll handle it gracefully
      // The app can still work with local flags only
      _isInitialized = false;
    }
  }

  @override
  Future<void> fetchAndActivate() async {
    if (!_isInitialized || _remoteConfig == null) {
      return;
    }

    try {
      await _remoteConfig!.fetchAndActivate();
    } on Exception {
      // If fetch fails, continue with cached/default values
      // This allows the app to work offline
    }
  }

  @override
  Future<bool?> getRemoteFlag(String key) async {
    if (!_isInitialized || _remoteConfig == null) {
      return null;
    }

    try {
      return _remoteConfig!.getBool(key);
    } on Exception {
      // If key doesn't exist or is not a bool, return null
      return null;
    }
  }

  @override
  Future<Map<String, bool>> getAllRemoteFlags() async {
    if (!_isInitialized || _remoteConfig == null) {
      return {};
    }

    try {
      final allKeys = _remoteConfig!.getAll();
      final flags = <String, bool>{};

      for (final entry in allKeys.entries) {
        try {
          // Try to get as bool
          final value = _remoteConfig!.getBool(entry.key);
          flags[entry.key] = value;
        } on Exception {
          // Skip non-bool values
        }
      }

      return flags;
    } on Exception {
      return {};
    }
  }

  @override
  Future<void> setDefaults(Map<String, dynamic> defaults) async {
    _defaultValues.addAll(defaults);
    if (_isInitialized && _remoteConfig != null) {
      await _remoteConfig!.setDefaults(defaults);
    }
  }
}
