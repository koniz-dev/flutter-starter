import 'package:flutter_starter/features/auth/domain/entities/user.dart';

/// User model (data layer) - extends entity
/// 
/// Note: Manual JSON serialization is used instead of @JsonSerializable
/// because UserModel extends User entity, and json_serializable doesn't
/// work well with inheritance. AuthResponseModel uses @JsonSerializable
/// since it doesn't have this limitation.
class UserModel extends User {
  /// Creates a [UserModel] with the given [id], [email], optional [name], and
  /// optional [avatarUrl]
  const UserModel({
    required super.id,
    required super.email,
    super.name,
    super.avatarUrl,
  });

  /// Create UserModel from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  /// Convert UserModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatar_url': avatarUrl,
    };
  }

  /// Convert UserModel to User entity
  User toEntity() {
    return User(
      id: id,
      email: email,
      name: name,
      avatarUrl: avatarUrl,
    );
  }
}
