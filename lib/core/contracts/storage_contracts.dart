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
/// Once its operations settle, an implementation must hold what they would
/// leave applied in the order they were issued: a successful clear issued
/// after a write removes that write's token, even if the write's platform
/// call completes later. A clear that fails throws, so its caller knows the
/// token may remain. The session guards in `AuthRepositoryImpl.refreshToken()`
/// and `AuthInterceptor` check the session immediately before a write and
/// rely on a logout's later clear removing it.
///
/// `SecureTokenStore` queues its operations to guarantee this, because the
/// platform store does not on every target. A call that outlives its wait
/// bound and lands late is followed by a repair, so the older value is at
/// rest only until that repair lands. A repair whose platform call keeps
/// failing is retried a bounded number of times, then reported to the logger
/// by key, and the late value stays until the next write or delete through
/// the same service re-applies the newer state. Its queue is
/// shared by every store over the same `SecureStorageService`, so the
/// components touching the tokens must use one service (or one store). An
/// in-memory store whose methods complete synchronously meets it trivially.
abstract class ITokenStore {
  Future<String?> getAccessToken();
  Future<bool> setAccessToken(String token);
  Future<void> clearAccessToken();

  Future<String?> getRefreshToken();
  Future<bool> setRefreshToken(String token);
  Future<void> clearRefreshToken();

  Future<void> clearAllTokens();
}
