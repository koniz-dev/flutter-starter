/// Base exception class
abstract class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});
}

/// Server exception
class ServerException extends AppException {
  final int? statusCode;

  const ServerException(
    super.message, {
    super.code,
    this.statusCode,
  });
}

/// Network exception
class NetworkException extends AppException {
  const NetworkException(super.message, {super.code});
}

/// Cache exception
class CacheException extends AppException {
  const CacheException(super.message, {super.code});
}

/// Validation exception
class ValidationException extends AppException {
  const ValidationException(super.message, {super.code});
}

/// Authentication exception
class AuthException extends AppException {
  const AuthException(super.message, {super.code});
}

