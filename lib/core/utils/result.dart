/// Result class for handling success and failure states
sealed class Result<T> {
  const Result();
}

/// Success result
final class Success<T> extends Result<T> {
  final T data;

  const Success(this.data);
}

/// Failure result
final class ResultFailure<T> extends Result<T> {
  final String message;
  final String? code;

  const ResultFailure(this.message, {this.code});
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
        ResultFailure<T>(:final message) => message,
      };

  /// Map the data if success
  Result<R> map<R>(R Function(T data) mapper) {
    return switch (this) {
      Success<T>(:final data) => Success(mapper(data)),
      ResultFailure<T>(:final message, :final code) =>
          ResultFailure<R>(message, code: code),
    };
  }

  /// Map the error if failure
  Result<T> mapError(String Function(String message) mapper) {
    return switch (this) {
      Success<T>() => this,
      ResultFailure<T>(:final message, :final code) => ResultFailure(
          mapper(message),
          code: code,
        ),
    };
  }

  /// Pattern matching helper
  R when<R>({
    required R Function(T data) success,
    required R Function(String message, String? code) failure,
  }) {
    return switch (this) {
      Success<T>(:final data) => success(data),
      ResultFailure<T>(:final message, :final code) => failure(message, code),
    };
  }
}

