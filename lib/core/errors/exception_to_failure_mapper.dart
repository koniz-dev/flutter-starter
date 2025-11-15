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
  /// - Unknown exceptions → UnknownFailure
  static Failure map(Exception exception) {
    return switch (exception) {
      ServerException(:final message, :final code) =>
        ServerFailure(message, code: code),
      NetworkException(:final message, :final code) =>
        NetworkFailure(message, code: code),
      CacheException(:final message, :final code) =>
        CacheFailure(message, code: code),
      AuthException(:final message, :final code) =>
        AuthFailure(message, code: code),
      ValidationException(:final message, :final code) =>
        ValidationFailure(message, code: code),
      _ => UnknownFailure(
          'Unexpected error: $exception',
          code: 'UNKNOWN_ERROR',
        ),
    };
  }
}
