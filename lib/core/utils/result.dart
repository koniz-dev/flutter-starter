import 'package:flutter_starter/core/errors/failures.dart';

/// Result class for handling success and failure states
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
final class ResultFailure<T> extends Result<T> {
  /// Creates a [ResultFailure] with the given [failure]
  const ResultFailure(this.failure);

  /// The typed failure containing error information
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

  /// Pattern matching helper
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
      ResultFailure<T>(:final failure) =>
        failureCallback(failure.message, failure.code),
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
  } else {
    // Fallback for any other failure types
    return UnknownFailure(newMessage, code: original.code);
  }
}
