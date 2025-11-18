/// Base exception class
abstract class AppException implements Exception {
  /// Creates an [AppException] with the given [message] and optional [code]
  const AppException(this.message, {this.code});

  /// Error message describing what went wrong
  final String message;

  /// Optional error code for programmatic error handling
  final String? code;
}

/// Server exception thrown when API requests fail
class ServerException extends AppException {
  /// Creates a [ServerException] with the given [message], optional [code],
  /// and optional [statusCode]
  const ServerException(
    super.message, {
    super.code,
    this.statusCode,
  });

  /// HTTP status code from the server response (e.g., 404, 500)
  final int? statusCode;
}

/// Network exception thrown when network requests fail
class NetworkException extends AppException {
  /// Creates a [NetworkException] with the given [message] and optional
  /// [code]
  const NetworkException(super.message, {super.code});
}

/// Cache exception thrown when local storage operations fail
class CacheException extends AppException {
  /// Creates a [CacheException] with the given [message] and optional [code]
  const CacheException(super.message, {super.code});
}

/// Validation exception thrown when input validation fails
class ValidationException extends AppException {
  /// Creates a [ValidationException] with the given [message] and optional
  /// [code]
  const ValidationException(super.message, {super.code});
}

/// Authentication exception thrown when authentication/authorization fails
class AuthException extends AppException {
  /// Creates an [AuthException] with the given [message] and optional [code]
  const AuthException(super.message, {super.code});
}
