/// What the router's redirect needs to know about the user's session.
///
/// Core declares it so `app_router.dart` names no feature. Whichever feature
/// owns sign-in supplies the value through `sessionStatusProvider` in
/// `routes_registry.dart`, the same seam that composes its routes.
enum SessionStatus {
  /// The persisted session is still being read back. Not the same as
  /// [signedOut]: the redirect holds the requested location instead of
  /// bouncing a returning user to `/login` for a frame.
  restoring,

  /// A user is signed in.
  signedIn,

  /// Nobody is signed in, and no restore is pending.
  signedOut,
}
