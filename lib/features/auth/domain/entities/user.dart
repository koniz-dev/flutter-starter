import 'package:flutter/foundation.dart';

/// User entity (domain layer)
@immutable
class User {
  /// Creates a [User] with the given [id], [email], optional [name], and
  /// optional [avatarUrl]
  const User({
    required this.id,
    required this.email,
    this.name,
    this.avatarUrl,
  });

  /// Unique user identifier
  final String id;

  /// User's email address
  final String email;

  /// User's display name
  final String? name;

  /// URL to user's avatar image
  final String? avatarUrl;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email;

  @override
  int get hashCode => id.hashCode ^ email.hashCode;
}
