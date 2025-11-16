import 'package:flutter_starter/core/storage/storage_service.dart';

/// Local data source for feature flags
///
/// Handles storing and retrieving local overrides for feature flags.
abstract class FeatureFlagsLocalDataSource {
  /// Get a local override for a feature flag
  Future<bool?> getLocalOverride(String key);

  /// Set a local override for a feature flag
  Future<void> setLocalOverride(String key, {required bool value});

  /// Clear a local override for a feature flag
  Future<void> clearLocalOverride(String key);

  /// Clear all local overrides
  Future<void> clearAllLocalOverrides();

  /// Get all local overrides
  Future<Map<String, bool>> getAllLocalOverrides();
}

/// Implementation of [FeatureFlagsLocalDataSource]
class FeatureFlagsLocalDataSourceImpl
    implements FeatureFlagsLocalDataSource {
  /// Creates a [FeatureFlagsLocalDataSourceImpl] with the given
  /// [storageService]
  FeatureFlagsLocalDataSourceImpl({
    required StorageService storageService,
  }) : _storageService = storageService;

  final StorageService _storageService;
  static const String _prefix = 'feature_flag_override_';

  @override
  Future<bool?> getLocalOverride(String key) async {
    final value = await _storageService.getString('$_prefix$key');
    if (value == null || value.isEmpty) {
      return null;
    }
    return value == 'true';
  }

  @override
  Future<void> setLocalOverride(String key, {required bool value}) async {
    await _storageService.setString('$_prefix$key', value.toString());
    await _addOverrideKey(key);
  }

  @override
  Future<void> clearLocalOverride(String key) async {
    await _storageService.remove('$_prefix$key');
    await _removeOverrideKey(key);
  }

  @override
  Future<void> clearAllLocalOverrides() async {
    // Store a list of override keys to track them
    final keysList =
        await _storageService.getStringList('${_prefix}keys') ?? [];
    for (final key in keysList) {
      await _storageService.remove('$_prefix$key');
    }
    await _storageService.remove('${_prefix}keys');
  }

  @override
  Future<Map<String, bool>> getAllLocalOverrides() async {
    final keysList =
        await _storageService.getStringList('${_prefix}keys') ?? [];
    final overrides = <String, bool>{};

    for (final key in keysList) {
      final value = await getLocalOverride(key);
      if (value != null) {
        overrides[key] = value;
      }
    }

    return overrides;
  }

  /// Internal method to track override keys
  Future<void> _addOverrideKey(String key) async {
    final keysList =
        await _storageService.getStringList('${_prefix}keys') ?? [];
    if (!keysList.contains(key)) {
      keysList.add(key);
      await _storageService.setStringList('${_prefix}keys', keysList);
    }
  }

  /// Internal method to remove override key from tracking
  Future<void> _removeOverrideKey(String key) async {
    final keysList =
        await _storageService.getStringList('${_prefix}keys') ?? [];
    if ((keysList..remove(key)).isEmpty) {
      await _storageService.remove('${_prefix}keys');
    } else {
      await _storageService.setStringList('${_prefix}keys', keysList);
    }
  }
}
