/// Notified when a session ends without the user asking for it.
///
/// The transport is where an expired session is *discovered*: `AuthInterceptor`
/// sees the 401, fails the refresh, and clears the persisted session. Nothing
/// there may reach into the feature holding the in-memory session, so the
/// feature implements this and hands it down - the same inversion
/// `IHttpResponseCache` uses in the opposite direction.
///
/// Implementations must be **best effort and non-throwing on their own terms**:
/// this is called from a `finally`-adjacent cleanup path whose only real job is
/// to complete the failing request's handler.
abstract class ISessionTerminationSink {
  /// Drops any in-memory session state.
  ///
  /// Persisted teardown (tokens, cached user, cached responses) has already
  /// run by the time this is called, so an implementation must not repeat it -
  /// and in particular must not call a logout endpoint, which would post with
  /// credentials that no longer exist.
  void onSessionTerminated();
}
