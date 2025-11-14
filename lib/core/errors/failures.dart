import 'package:equatable/equatable.dart';

/// Base class for all failures
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
