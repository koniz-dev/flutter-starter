import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

/// User model (data layer) - extends entity
///
/// Uses @JsonSerializable for code generation. Since UserModel extends User
/// entity, we use @JsonKey annotations on getters to handle field name mapping
/// (avatarUrl -> avatar_url) while maintaining the inheritance structure.
@JsonSerializable()
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
  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  /// JSON key mapping for avatarUrl field
  @JsonKey(name: 'avatar_url')
  @override
  String? get avatarUrl => super.avatarUrl;

  /// Convert UserModel to JSON
  Map<String, dynamic> toJson() => _$UserModelToJson(this);
}
