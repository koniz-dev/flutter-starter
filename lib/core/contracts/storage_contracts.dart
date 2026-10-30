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
///
/// An implementation must apply its operations in the order they are issued:
/// a clear issued after a write lands after that write. The session guards in
/// `AuthRepositoryImpl.refreshToken()` and `AuthInterceptor` check the session
/// immediately before a write and rely on a logout's later clear removing it.
/// `SecureTokenStore` queues its operations to guarantee this, because the
/// platform store does not on every target. An in-memory store whose methods
/// complete synchronously meets it trivially.
abstract class ITokenStore {
  Future<String?> getAccessToken();
  Future<bool> setAccessToken(String token);
  Future<void> clearAccessToken();

  Future<String?> getRefreshToken();
  Future<bool> setRefreshToken(String token);
  Future<void> clearRefreshToken();

  Future<void> clearAllTokens();
}
