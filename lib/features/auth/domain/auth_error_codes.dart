/// Structured error codes the auth slice uses to decide the fate of a session.
///
/// A session-lifetime decision must never rest on a failure's free-text
/// `message`: the message is server-supplied, localisable and reworded without
/// notice, so matching on it both fires when it should not and stays silent
/// when it should fire (koniz-dev/flutter-starter#181). Every path that means
/// "this session cannot be revived" sets [refreshTokenExpired] explicitly, and
/// the presentation layer reads only that.
class AuthErrorCodes {
  AuthErrorCodes._();

  /// The stored refresh token can no longer produce an access token.
  ///
  /// Set when the refresh endpoint rejects the token with 401, and when there
  /// is no refresh token on the device at all - both mean the same thing to a
  /// caller, that only a fresh sign-in can restore the session. This is the
  /// only code that forces a logout.
  static const String refreshTokenExpired = 'REFRESH_TOKEN_EXPIRED';

  /// The session ended while a token refresh was still in flight.
  ///
  /// Deliberately **not** a forced logout: whoever ended the session already
  /// tore it down, and a newer sign-in may already own the credentials on the
  /// device. See koniz-dev/flutter-starter#169.
  static const String sessionTerminated = 'SESSION_TERMINATED';
}
