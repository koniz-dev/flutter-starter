import 'package:flutter_starter/core/errors/failures.dart';

/// Result class for handling success and failure states
///
/// This is a sealed class that represents either a successful operation
/// ([Success]) or a failed operation ([ResultFailure]).
///
/// Uses Dart 3.0 pattern matching for type-safe handling of success/failure
/// states. The [when] method provides a convenient way to handle both cases
/// using switch expressions.
///
/// Example:
/// ```dart
/// final result = await someOperation();
/// result.when(
///   success: (data) => print('Success: $data'),
///   failureCallback: (failure) => print('Error: ${failure.message}'),
/// );
/// ```
sealed class Result<T> {
  /// Creates a [Result] instance
  const Result();
}

/// Success result containing data of type [T]
final class Success<T> extends Result<T> {
  /// Creates a [Success] result with the given [data]
  const Success(this.data);

  /// The successful data value
  final T data;
}

/// Failure result containing typed failure information
///
/// [ResultFailure] is a wrapper around a [Failure] object that represents
/// a failed operation. The relationship is:
///
/// - **ResultFailure**: A variant of [Result] that represents failure.
///   It wraps a [Failure] object which contains the actual error information.
///
/// - **Failure**: The base class for all typed failures (e.g., [ServerFailure],
///   [NetworkFailure], [AuthFailure]). It contains the error message and
///   optional error code.
///
/// This separation allows:
/// - Type-safe error handling at the Result level
/// - Typed failure information at the Failure level
/// - Pattern matching on both Result and Failure types
///
/// Example:
/// ```dart
/// final result = ResultFailure<User>(ServerFailure('Server error'));
/// // result.failure is a ServerFailure instance
/// // result.message is 'Server error'
/// ```
final class ResultFailure<T> extends Result<T> {
  /// Creates a [ResultFailure] with the given [failure]
  const ResultFailure(this.failure);

  /// The typed failure containing error information
  ///
  /// This is a [Failure] instance (or one of its subtypes like
  /// [ServerFailure], [NetworkFailure], etc.) that contains the actual
  /// error details.
  final Failure failure;

  /// Error message from the failure (convenience getter)
  String get message => failure.message;

  /// Error code from the failure (convenience getter)
  String? get code => failure.code;
}

/// Extension methods for Result
extension ResultExtensions<T> on Result<T> {
  /// Check if result is success
  bool get isSuccess => this is Success<T>;

  /// Check if result is failure
  bool get isFailure => this is ResultFailure<T>;

  /// Get data if success, null otherwise
  T? get dataOrNull => switch (this) {
    Success<T>(:final data) => data,
    ResultFailure<T>() => null,
  };

  /// Get error message if failure, null otherwise
  String? get errorOrNull => switch (this) {
    Success<T>() => null,
    ResultFailure<T>(:final failure) => failure.message,
  };

  /// Get typed failure if failure, null otherwise
  Failure? get failureOrNull => switch (this) {
    Success<T>() => null,
    ResultFailure<T>(:final failure) => failure,
  };

  /// Map the data if success
  Result<R> map<R>(R Function(T data) mapper) {
    return switch (this) {
      Success<T>(:final data) => Success(mapper(data)),
      ResultFailure<T>(:final failure) => ResultFailure<R>(failure),
    };
  }

  /// Map the error if failure
  Result<T> mapError(String Function(String message) mapper) {
    return switch (this) {
      Success<T>() => this,
      ResultFailure<T>(:final failure) => ResultFailure<T>(
        _createFailureWithMessage(failure, mapper(failure.message)),
      ),
    };
  }

  /// Pattern matching helper using Dart 3.0 switch expressions
  ///
  /// This method uses Dart 3.0 pattern matching to safely handle both
  /// success and failure cases. It provides type-safe access to the data
  /// or failure information.
  ///
  /// The method uses a switch expression internally, which ensures:
  /// - Exhaustive pattern matching (all cases must be handled)
  /// - Type safety (data is of type T, failure is of type Failure)
  /// - No null safety issues
  ///
  /// Parameters:
  /// - [success]: Callback invoked when the result is a [Success].
  ///   Receives the data of type [T].
  /// - [failureCallback]: Callback invoked when the result is a
  ///   [ResultFailure]. Receives the [Failure] object (which may be a
  ///   subtype like [ServerFailure], [NetworkFailure], etc.).
  ///
  /// Returns:
  /// The result of the callback that matches the result type.
  ///
  /// Example:
  /// ```dart
  /// final result = await loginUseCase(email, password);
  /// result.when(
  ///   success: (user) {
  ///     // user is of type User
  ///     print('Logged in: ${user.email}');
  ///   },
  ///   failureCallback: (failure) {
  ///     // failure is of type Failure (may be AuthFailure, etc.)
  ///     print('Error: ${failure.message}');
  ///     if (failure is AuthFailure) {
  ///       // Can pattern match on Failure subtypes too
  ///       print('Auth error code: ${failure.code}');
  ///     }
  ///   },
  /// );
  /// ```
  R when<R>({
    required R Function(T data) success,
    required R Function(Failure failure) failureCallback,
  }) {
    return switch (this) {
      Success<T>(:final data) => success(data),
      ResultFailure<T>(:final failure) => failureCallback(failure),
    };
  }

  /// Pattern matching helper with legacy signature for backward compatibility
  @Deprecated('Use when() with Failure parameter instead')
  R whenLegacy<R>({
    required R Function(T data) success,
    required R Function(String message, String? code) failureCallback,
  }) {
    return switch (this) {
      Success<T>(:final data) => success(data),
      ResultFailure<T>(:final failure) => failureCallback(
        failure.message,
        failure.code,
      ),
    };
  }
}

/// Helper to create a new failure with updated message
Failure _createFailureWithMessage(Failure original, String newMessage) {
  if (original is ServerFailure) {
    return ServerFailure(newMessage, code: original.code);
  } else if (original is NetworkFailure) {
    return NetworkFailure(newMessage, code: original.code);
  } else if (original is CacheFailure) {
    return CacheFailure(newMessage, code: original.code);
  } else if (original is AuthFailure) {
    return AuthFailure(newMessage, code: original.code);
  } else if (original is ValidationFailure) {
    return ValidationFailure(newMessage, code: original.code);
  } else if (original is PermissionFailure) {
    return PermissionFailure(newMessage, code: original.code);
  } else if (original is UnknownFailure) {
    return UnknownFailure(newMessage, code: original.code);
  } else if (original is NotFoundFailure) {
    return NotFoundFailure(newMessage, code: original.code);
  } else {
    // Fallback for any other failure types
    return UnknownFailure(newMessage, code: original.code);
  }
}
