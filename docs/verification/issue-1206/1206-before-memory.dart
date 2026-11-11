/// In-memory stand-ins for the two storage services that talk to a platform
/// channel.
///
/// Use these whenever a test assembles the real provider graph.
/// `StorageService` is SharedPreferences-backed and `SecureTokenStore` is
/// Keychain-backed; with neither channel mocked a `flutter test` **hangs** on
/// the first read rather than failing, which is a much worse failure mode to
/// debug.
///
/// They are real implementations, not mocks: tests assert on what was actually
/// persisted rather than on which methods happened to be called.
library;

import 'dart:async';

import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';

/// A real [StorageService] backed by a map.
class InMemoryStorage implements StorageService {
  /// Everything currently persisted, for direct assertion.
  final Map<String, Object?> values = {};

  @override
  Future<void> init() async {}

  @override
  Future<bool> clear() async {
    values.clear();
    return true;
  }

  @override
  Future<bool> containsKey(String key) async => values.containsKey(key);

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }

  @override
  Future<String?> getString(String key) async => values[key] as String?;

  @override
  Future<bool> setString(String key, String value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<int?> getInt(String key) async => values[key] as int?;

  @override
  Future<bool> setInt(String key, int value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;

  @override
  Future<bool> setBool(String key, {required bool value}) async {
    values[key] = value;
    return true;
  }

  @override
  Future<double?> getDouble(String key) async => values[key] as double?;

  @override
  Future<bool> setDouble(String key, double value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<List<String>?> getStringList(String key) async =>
      values[key] as List<String>?;

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    values[key] = value;
    return true;
  }
}

/// A real [ITokenStore] backed by two fields.
class InMemoryTokenStore implements ITokenStore {
  String? _accessToken;
  String? _refreshToken;
  Object _revision = Object();
  int _pendingMutations = 0;

  /// The stored access token, for direct assertion/seeding.
  String? get accessToken => _accessToken;
  set accessToken(String? value) {
    _revision = Object();
    _accessToken = value;
  }

  /// The stored refresh token, for direct assertion/seeding.
  String? get refreshToken => _refreshToken;
  set refreshToken(String? value) {
    _revision = Object();
    _refreshToken = value;
  }

  /// Subclasses with delayed mutation hooks must track their whole operation.
  Future<T> trackCredentialMutation<T>(FutureOr<T> Function() operation) {
    _revision = Object();
    _pendingMutations++;
    return Future<T>.sync(operation).whenComplete(() => _pendingMutations--);
  }

  @override
  Object get credentialRevision => _revision;

  @override
  Future<AccessTokenSnapshot?> getAccessTokenSnapshot() async {
    if (_pendingMutations != 0) return null;
    final revision = _revision;
    final token = await getAccessToken();
    if (_pendingMutations != 0 || !identical(revision, _revision)) return null;
    return AccessTokenSnapshot(token: token, revision: revision);
  }

  @override
  Future<AccessTokenWriteResult> setAccessTokenIfCurrent(
    AccessTokenSnapshot expected,
    String token,
  ) {
    if (_pendingMutations != 0 || !identical(expected.revision, _revision)) {
      return Future.value(AccessTokenWriteResult.conflict);
    }
    accessToken = token;
    return Future.value(AccessTokenWriteResult.applied);
  }

  @override
  Future<void> clearAccessToken() => trackCredentialMutation(() {
    _accessToken = null;
  });

  @override
  Future<void> clearAllTokens() => trackCredentialMutation(() {
    _accessToken = null;
    _refreshToken = null;
  });

  @override
  Future<void> clearRefreshToken() => trackCredentialMutation(() {
    _refreshToken = null;
  });

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<bool> setAccessToken(String token) => trackCredentialMutation(() {
    _accessToken = token;
    return true;
  });

  @override
  Future<bool> setRefreshToken(String token) => trackCredentialMutation(() {
    _refreshToken = token;
    return true;
  });
}

/// A real [IKeyValueStore] backed by a map.
///
/// Unlike [InMemoryStorage] this implements **only** the contract, not the
/// concrete `StorageService`. A data source that accepts one of these is
/// provably decoupled from SharedPreferences: the seam is real, not nominal.
class InMemoryKeyValueStore implements IKeyValueStore {
  /// Everything currently persisted, for direct assertion.
  final Map<String, Object?> values = {};

  @override
  Future<bool> clear() async {
    values.clear();
    return true;
  }

  @override
  Future<bool> containsKey(String key) async => values.containsKey(key);

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }

  @override
  Future<String?> getString(String key) async => values[key] as String?;

  @override
  Future<bool> setString(String key, String value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<int?> getInt(String key) async => values[key] as int?;

  @override
  Future<bool> setInt(String key, int value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;

  @override
  Future<bool> setBool(String key, {required bool value}) async {
    values[key] = value;
    return true;
  }

  @override
  Future<double?> getDouble(String key) async => values[key] as double?;

  @override
  Future<bool> setDouble(String key, double value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<List<String>?> getStringList(String key) async =>
      values[key] as List<String>?;

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    values[key] = List<String>.from(value);
    return true;
  }
}
