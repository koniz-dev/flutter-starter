import 'dart:async';

/// Identifies which sign-in the credentials on this device belong to.
///
/// A token refresh spans a network round trip, and a logout, a forced logout
/// or a fresh sign-in can replace the credentials meanwhile; its response must
/// then not be persisted. A caller reads [current] **before** the round trip
/// and checks [isCurrent] **immediately before** each write; any [invalidate]
/// in between makes the check fail and the write is dropped.
///
/// A counter, not a `terminated` flag: a flag would read "signed in" again
/// after a new sign-in, and an old refresh would land on the new user's
/// tokens. A generation left behind never becomes current again.
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
/// A stale refresh **skips** its writes and clears nothing: the store may
/// already hold the session that replaced it.
///
/// ## Threading
///
/// [current], [invalidate] and [isCurrent] are synchronous and cannot
/// interleave; the window this guards is an `await`, so a plain `int`
/// suffices.
///
/// ## Teardowns
///
/// Ending a session is synchronous ([invalidate]); clearing what it stored is
/// not. Each logout path registers its clearing with [trackTeardown] before
/// it invalidates, and a sign-in waits on [teardownsSettled] before it calls
/// the server, so a teardown still running cannot delete the credentials of
/// the sign-in that followed it.
/// Sign-in persistence registers its entire local mutation too: an earlier
/// user-blob write or failed-write cleanup must settle before the next sign-in
/// can replace that session. The same bounded wait covers both operations.
///
/// ## Observing a session change
///
/// Every [invalidate] also notifies the listeners added with [addListener].
/// That is how per-user state outside the auth slice - which may not import
/// it - learns the user changed and resets.
/// Most callers should listen through `sessionEpochProvider` rather than here.
///
/// A plain listener list rather than a `ChangeNotifier`: a forced logout can
/// land after the owning provider container is gone, and must then notify
/// nobody instead of tripping a use-after-dispose assertion.
class SessionGeneration {
  int _current = 0;
  final List<void Function()> _listeners = [];

  /// Calls [listener] after every [invalidate].
  void addListener(void Function() listener) => _listeners.add(listener);

  /// Stops calling [listener].
  void removeListener(void Function() listener) => _listeners.remove(listener);

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
  ///
  /// Never throws. The logout paths call it unguarded right before clearing
  /// the stored tokens, so a listener that throws must not skip that teardown:
  /// each listener's error goes to the current zone's uncaught-error handler
  /// and the remaining listeners still run.
  void invalidate() {
    _current++;
    // A copy, so a listener that removes itself does not skip its neighbour.
    for (final listener in List.of(_listeners)) {
      try {
        listener();
      } on Object catch (error, stackTrace) {
        Zone.current.handleUncaughtError(error, stackTrace);
      }
    }
  }

  /// Whether [generation] is still the live one.
  ///
  /// False once anything has called [invalidate] since [generation] was read.
  bool isCurrent(int generation) => generation == _current;

  final Set<Future<void>> _teardowns = {};
  final Set<Future<void>> _persistence = {};

  /// Whether credentials/user data are currently being replaced or rolled back.
  bool get hasPendingPersistence => _persistence.isNotEmpty;

  /// Tracks a sign-in's complete local write/rollback operation.
  ///
  /// New sign-ins wait for it through [teardownsSettled]. Restore reads wait
  /// through [persistenceSettled] so they cannot mistake the interval between
  /// credential and user writes for an orphaned session and evict it. Those
  /// reads do not wait for a logout's remote revocation acknowledgement.
  /// The returned future completes after the restore/refresh guard is removed.
  Future<void> trackPersistence(Future<void> operation) {
    final settled = operation.then<void>((_) {}, onError: (Object _) {});
    _persistence.add(settled);
    trackTeardown(settled);
    return settled.whenComplete(() => _persistence.remove(settled));
  }

  /// Waits for local sign-in persistence to settle, including rollback.
  Future<bool> persistenceSettled(Duration limit) =>
      _waitFor(_persistence, limit);

  /// Records [teardown] - local session writes or clearing - until it settles,
  /// so a sign-in can wait for it with [teardownsSettled].
  ///
  /// A teardown deletes whatever credentials are stored when its steps run,
  /// so a sign-in must not store its own while one is still running.
  void trackTeardown(Future<void> teardown) {
    final settled = teardown.then<void>((_) {}, onError: (Object _) {});
    _teardowns.add(settled);
    unawaited(settled.whenComplete(() => _teardowns.remove(settled)));
  }

  /// Waits until no tracked teardown is running, including one tracked while
  /// waiting. False when that takes longer than [limit].
  Future<bool> teardownsSettled(Duration limit) => _waitFor(_teardowns, limit);

  Future<bool> _waitFor(Set<Future<void>> pending, Duration limit) async {
    final waited = Stopwatch()..start();
    while (pending.isNotEmpty) {
      final left = limit - waited.elapsed;
      if (left <= Duration.zero) return false;
      try {
        await Future.wait(pending.toList()).timeout(left);
      } on TimeoutException {
        return false;
      }
    }
    return true;
  }
}
