import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/errors/failures.dart';

/// Mapper for converting domain exceptions to typed failures
class ExceptionToFailureMapper {
  /// Converts a domain exception to an appropriate typed failure
  ///
  /// Maps different exception types to their corresponding failure types:
  /// - ServerException → ServerFailure
  /// - NetworkException → NetworkFailure
  /// - CacheException → CacheFailure
  /// - AuthException → AuthFailure
  /// - ValidationException → ValidationFailure
  /// - PermissionException → PermissionFailure
  /// - NotFoundException → NotFoundFailure
  /// - any other [AppException] → UnknownFailure carrying its message and
  ///   code, rather than an interpolation of the exception object
  /// - anything else → UnknownFailure describing the exception
  static Failure map(Exception exception) {
    return switch (exception) {
      ServerException(:final message, :final code) => ServerFailure(
        message,
        code: code,
      ),
      NetworkException(:final message, :final code) => NetworkFailure(
        message,
        code: code,
      ),
      CacheException(:final message, :final code) => CacheFailure(
        message,
        code: code,
      ),
      AuthException(:final message, :final code) => AuthFailure(
        message,
        code: code,
      ),
      ValidationException(:final message, :final code) => ValidationFailure(
        message,
        code: code,
      ),
      PermissionException(:final message, :final code) => PermissionFailure(
        message,
        code: code,
      ),
      NotFoundException(:final message, :final code) => NotFoundFailure(
        message,
        code: code,
      ),
      // An AppException subclass the template does not know about still
      // carries a usable message and code; keep them instead of collapsing
      // to 'Unexpected error: Instance of ...'.
      AppException(:final message, :final code) => UnknownFailure(
        message,
        code: code ?? 'UNKNOWN_ERROR',
      ),
      _ => UnknownFailure(
        'Unexpected error: $exception',
        code: 'UNKNOWN_ERROR',
      ),
    };
  }
}
