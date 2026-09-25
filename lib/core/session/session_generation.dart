/// Identifies which sign-in the credentials on this device belong to.
///
/// A token refresh is a read-modify-write that spans a full network round
/// trip, and the thing it writes back - the access and refresh tokens - is
/// shared mutable state that a logout, a forced logout, or a fresh sign-in can
/// replace while that round trip is still open. Nothing in the refresh path
/// used to notice, so a logout that landed mid-refresh was silently undone:
/// the response came back and re-persisted a live credential pair onto a
/// device the user had just signed out of
/// (koniz-dev/flutter-starter#169).
///
/// This is the marker that makes such a write detectable. A caller reads
/// [current] **before** it starts the round trip and checks [isCurrent]
/// **immediately before** it persists anything. Any call to [invalidate] in
/// between makes that check fail, and the write is dropped.
///
/// ## Why a counter rather than a `terminated` flag
///
/// A boolean answers "is there a session right now", which is the wrong
/// question. Signing back in while an old refresh is still in flight sets it
/// false again and the stale response lands on top of the **new** user's
/// tokens. A monotonically increasing counter answers the right question -
/// "is this still the same session I started under" - and a generation that
/// has been left behind can never become current again.
///
/// ## What must invalidate
///
/// Every transition that replaces or removes the credential set:
///
/// - `AuthRepositoryImpl.logout()` - the user signed out.
/// - `AuthInterceptor._logoutUser()` - a forced logout after a failed refresh
///   or an exhausted retry.
/// - `AuthRepositoryImpl.login()` / `register()` - a *different* credential
///   set is about to be written, and an older refresh must not overwrite it.
///
/// Note what is deliberately absent: a stale refresh **skips** its writes, it
/// does not undo them. Clearing the store on detection would destroy the
/// tokens of a session that started during the refresh, which is the very case
/// the counter exists to protect.
///
/// ## Threading
///
/// Dart is single-threaded per isolate, so [current], [invalidate] and
/// [isCurrent] are all synchronous and cannot interleave with each other. The
/// window this guards is an `await`, not a preemption, which is why an
/// ordinary `int` is sufficient and no lock is involved.
class SessionGeneration {
  int _current = 0;

  /// The generation a credential write must still belong to in order to land.
  ///
  /// Read this before starting any operation that will persist a token, and
  /// pass the value to [isCurrent] once the operation completes.
  int get current => _current;

  /// Ends the current generation, so work started under it can no longer
  /// persist anything.
  ///
  /// Synchronous and idempotent in effect: calling it twice simply skips two
  /// generations. Call it *before* the `await`s that perform the teardown, so
  /// a refresh resolving part-way through the teardown is already stale.
  void invalidate() {
    _current++;
  }

  /// Whether [generation] is still the live one.
  ///
  /// False once anything has called [invalidate] since [generation] was read.
  bool isCurrent(int generation) => generation == _current;
}
