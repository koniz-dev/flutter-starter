import 'package:equatable/equatable.dart';

/// Base class for all failures
///
/// [Failure] represents typed error information in the domain layer.
/// It is used within ResultFailure (from `result.dart`) to provide
/// type-safe error handling.
///
/// **Relationship with ResultFailure:**
///
/// - **Failure**: The domain-level error representation. Contains error
///   message and optional code. Has typed subclasses (e.g., [ServerFailure],
///   [NetworkFailure], [AuthFailure]).
///
/// - **ResultFailure**: A wrapper in the Result type system that contains
///   a [Failure] instance. It represents a failed operation.
///
/// **Usage Pattern:**
///
/// ```dart
/// // Create a typed failure
/// final failure = ServerFailure('Server error', code: '500');
///
/// // Wrap it in a ResultFailure
/// final result = ResultFailure<User>(failure);
///
/// // Use pattern matching
/// result.when(
///   success: (user) => print('User: $user'),
///   failureCallback: (failure) {
///     // failure is the ServerFailure instance
///     if (failure is ServerFailure) {
///       print('Server error: ${failure.message}');
///     }
///   },
/// );
/// ```
///
/// **Failure Subtypes:**
///
/// - [ServerFailure]: API/server errors
/// - [NetworkFailure]: Network connectivity issues
/// - [CacheFailure]: Local storage errors
/// - [AuthFailure]: Authentication/authorization errors
/// - [ValidationFailure]: Input validation errors
/// - [PermissionFailure]: Permission denied errors
/// - [UnknownFailure]: Unclassified errors
abstract class Failure extends Equatable {
  /// Creates a [Failure] with the given [message] and optional [code]
  const Failure(this.message, {this.code});

  /// Error message describing what went wrong
  final String message;

  /// Optional error code for programmatic error handling
  final String? code;

  @override
  List<Object?> get props => [message, code];
}

/// Server failure thrown when API requests fail
class ServerFailure extends Failure {
  /// Creates a [ServerFailure] with the given [message] and optional [code]
  const ServerFailure(super.message, {super.code});
}

/// Network failure thrown when network requests fail
class NetworkFailure extends Failure {
  /// Creates a [NetworkFailure] with the given [message] and optional [code]
  const NetworkFailure(super.message, {super.code});
}

/// Cache failure thrown when local storage operations fail
class CacheFailure extends Failure {
  /// Creates a [CacheFailure] with the given [message] and optional [code]
  const CacheFailure(super.message, {super.code});
}

/// Validation failure thrown when input validation fails
class ValidationFailure extends Failure {
  /// Creates a [ValidationFailure] with the given [message] and optional
  /// [code]
  const ValidationFailure(super.message, {super.code});
}

/// Authentication failure thrown when authentication/authorization fails
class AuthFailure extends Failure {
  /// Creates an [AuthFailure] with the given [message] and optional [code]
  const AuthFailure(super.message, {super.code});
}

/// Permission failure thrown when user lacks required permissions
class PermissionFailure extends Failure {
  /// Creates a [PermissionFailure] with the given [message] and optional
  /// [code]
  const PermissionFailure(super.message, {super.code});
}

/// Unknown failure thrown when the error type cannot be determined
class UnknownFailure extends Failure {
  /// Creates an [UnknownFailure] with the given [message] and optional
  /// [code]
  const UnknownFailure(super.message, {super.code});
}

/// Not found failure thrown when a requested resource is not found
class NotFoundFailure extends Failure {
  /// Creates a [NotFoundFailure] with the given [message] and optional
  /// [code]
  const NotFoundFailure(super.message, {super.code});
}
