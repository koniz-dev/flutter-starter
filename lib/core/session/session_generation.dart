import 'dart:async';

/// Identifies which sign-in the credentials on this device belong to.
///
/// A token refresh is a read-modify-write that spans a full network round
/// trip, and the thing it writes back - the access and refresh tokens - is
/// shared mutable state that a logout, a forced logout, or a fresh sign-in can
/// replace while that round trip is still open. Nothing in the refresh path
/// used to notice, so a logout that landed mid-refresh was silently undone:
/// the response came back and re-persisted a live credential pair onto a
/// device the user had just signed out of.
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
///
/// ## Teardowns
///
/// Ending a session is synchronous ([invalidate]); clearing what it stored is
/// not. Each logout path registers its clearing with [trackTeardown] before
/// it invalidates, and a sign-in waits on [teardownsSettled] before it calls
/// the server, so a teardown still running cannot delete the credentials of
/// the sign-in that followed it.
///
/// ## Observing a session change
///
/// Every [invalidate] also notifies the listeners added with [addListener].
/// That is how per-user state outside the auth slice - which may not import
/// it - learns the user changed and resets.
/// Most callers should listen through `sessionEpochProvider` rather than here.
///
/// A plain listener list rather than a `ChangeNotifier`, on purpose: there is
/// no disposed state. A forced logout can land after the provider container
/// that owned this instance is gone, and it must then notify nobody
/// rather than trip a use-after-dispose assertion.
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

  /// Records [teardown] - the clearing that follows an [invalidate] - until
  /// it settles, so a sign-in can wait for it with [teardownsSettled].
  ///
  /// A teardown deletes whatever credentials are stored when its steps run.
  /// A sign-in that stored its own while one was still running - a user
  /// logout waiting on its server call, or `AuthInterceptor`'s forced logout
  /// waiting on a slow keychain - had them deleted, after reporting success.
  void trackTeardown(Future<void> teardown) {
    final settled = teardown.then<void>((_) {}, onError: (Object _) {});
    _teardowns.add(settled);
    unawaited(settled.whenComplete(() => _teardowns.remove(settled)));
  }

  /// Waits until no tracked teardown is running, including one tracked while
  /// waiting. False when that takes longer than [limit].
  Future<bool> teardownsSettled(Duration limit) async {
    final waited = Stopwatch()..start();
    while (_teardowns.isNotEmpty) {
      final left = limit - waited.elapsed;
      if (left <= Duration.zero) return false;
      try {
        await Future.wait(_teardowns.toList()).timeout(left);
      } on TimeoutException {
        return false;
      }
    }
    return true;
  }
}
