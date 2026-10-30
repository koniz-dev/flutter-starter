import 'dart:async';

import 'package:flutter_starter/core/contracts/storage_contracts.dart';

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
class FeatureFlagsLocalDataSourceImpl implements FeatureFlagsLocalDataSource {
  /// Creates a [FeatureFlagsLocalDataSourceImpl] with the given
  /// [storageService]
  FeatureFlagsLocalDataSourceImpl({required IKeyValueStore storageService})
    : _storageService = storageService;

  final IKeyValueStore _storageService;
  static const String _prefix = 'feature_flag_override_';

  /// The last queued index update. The override index is read, changed and
  /// written back; two overrides set together - the debug screen's switches
  /// call setLocalOverride with no pending guard - each read the same old
  /// list and the second write dropped the first key, which
  /// clearAllLocalOverrides then never cleared. Every index change runs after
  /// the previous one, as CacheInterceptor does for its own index.
  Future<void>? _indexQueue;

  Future<void> _serializedIndexUpdate(Future<void> Function() update) async {
    final previous = _indexQueue;
    final done = Completer<void>();
    _indexQueue = done.future;
    try {
      if (previous != null) await previous;
      await update();
    } finally {
      done.complete();
      if (identical(_indexQueue, done.future)) _indexQueue = null;
    }
  }

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
  Future<void> clearAllLocalOverrides() => _serializedIndexUpdate(() async {
    final keysList =
        await _storageService.getStringList('${_prefix}keys') ?? [];
    for (final key in keysList) {
      await _storageService.remove('$_prefix$key');
    }
    await _storageService.remove('${_prefix}keys');
  });

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
  Future<void> _addOverrideKey(String key) => _serializedIndexUpdate(() async {
    final keysList =
        await _storageService.getStringList('${_prefix}keys') ?? [];
    if (!keysList.contains(key)) {
      keysList.add(key);
      await _storageService.setStringList('${_prefix}keys', keysList);
    }
  });

  /// Internal method to remove override key from tracking
  Future<void> _removeOverrideKey(String key) =>
      _serializedIndexUpdate(() async {
        final keysList =
            await _storageService.getStringList('${_prefix}keys') ?? [];
        if ((keysList..remove(key)).isEmpty) {
          await _storageService.remove('${_prefix}keys');
        } else {
          await _storageService.setStringList('${_prefix}keys', keysList);
        }
      });
}
