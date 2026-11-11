// Lightweight boundary contract file; repetitive per-member docs are omitted.
// ignore_for_file: public_member_api_docs

/// Generic key-value storage contract for non-sensitive values.
///
/// Mutations can report failure by returning `false` as well as by throwing.
/// Callers must check the result before reporting success, deleting source
/// data during a migration, or treating session cleanup as complete.
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

/// A certified access-token value and an opaque credential revision.
///
/// A null [token] is a valid cleared state. Compare [revision] by identity;
/// revisions are transient and must not be persisted or reconstructed.
class AccessTokenSnapshot {
  const AccessTokenSnapshot({required this.token, required this.revision});

  final String? token;
  final Object revision;
}

/// Outcome of a conditional access-token write.
enum AccessTokenWriteResult {
  /// The write succeeded without being superseded at its completion point.
  applied,

  /// Another mutation or uncertain pending operation took precedence.
  conflict,

  /// The platform reported failure without a superseding mutation.
  failed,
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
/// by key; reads of that key then answer from memory with the newer state,
/// and the next write through the same service (or, for a key whose newer
/// state is a delete, the next delete or read of it) re-applies it. The
/// marker is in memory, so if the app stops first, the next launch reads the
/// late value.
/// Its queue is shared by every store over the same `SecureStorageService`,
/// so the components touching the tokens must use one service (or one store).
/// An in-memory store whose methods complete synchronously meets it
/// trivially.
abstract class ITokenStore {
  /// Changes synchronously whenever any credential write/delete is issued,
  /// even if it later fails. Stores over one backing service share revisions.
  /// A write/delete cycle back to the same value must still change it.
  /// Internal repairs reapply an existing mutation, not a newer credential.
  Object get credentialRevision;

  /// Certifies the value/revision after the read, or returns null when a
  /// pending/bypassed operation or concurrent mutation makes it uncertain.
  /// Implementations bound retries/waits; read failures may still throw.
  /// Certification is a selection point, not a lock through a network call.
  /// Before acting, callers compare its revision with [credentialRevision]
  /// again; a mismatch requires a new selection or rejection without teardown.
  Future<AccessTokenSnapshot?> getAccessTokenSnapshot();

  /// Compares and reserves mutation order synchronously at invocation, before
  /// any await. A foreign/stale snapshot cannot write. Later-issued mutations
  /// retain precedence, including writes that bypass a bounded queue wait.
  Future<AccessTokenWriteResult> setAccessTokenIfCurrent(
    AccessTokenSnapshot expected,
    String token,
  );

  Future<String?> getAccessToken();
  Future<bool> setAccessToken(String token);
  Future<void> clearAccessToken();

  Future<String?> getRefreshToken();
  Future<bool> setRefreshToken(String token);
  Future<void> clearRefreshToken();

  Future<void> clearAllTokens();
}
