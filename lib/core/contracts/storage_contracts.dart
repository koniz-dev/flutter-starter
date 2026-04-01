// Lightweight boundary contract file; repetitive per-member docs are omitted.
// ignore_for_file: public_member_api_docs

/// Generic key-value storage contract for non-sensitive values.
abstract class IKeyValueStore {
  Future<String?> getString(String key);
  Future<bool> setString(String key, String value);

  Future<int?> getInt(String key);
  Future<bool> setInt(String key, int value);

  Future<bool?> getBool(String key);
  Future<bool> setBool(String key, {required bool value});

  Future<double?> getDouble(String key);
  Future<bool> setDouble(String key, double value);

  Future<List<String>?> getStringList(String key);
  Future<bool> setStringList(String key, List<String> value);

  Future<bool> remove(String key);
  Future<bool> clear();
  Future<bool> containsKey(String key);
}

/// Dedicated token/session storage contract.
abstract class ITokenStore {
  Future<String?> getAccessToken();
  Future<bool> setAccessToken(String token);
  Future<void> clearAccessToken();

  Future<String?> getRefreshToken();
  Future<bool> setRefreshToken(String token);
  Future<void> clearRefreshToken();

  Future<void> clearAllTokens();
}
