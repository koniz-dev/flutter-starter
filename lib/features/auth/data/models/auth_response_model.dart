import 'package:flutter_starter/features/auth/data/models/user_model.dart';
import 'package:json_annotation/json_annotation.dart';

part 'auth_response_model.g.dart';

/// Authentication response model containing user and token
@JsonSerializable()
class AuthResponseModel {
  /// Creates an [AuthResponseModel] with [user], [token], and optional
  /// [refreshToken]
  const AuthResponseModel({
    required this.user,
    required this.token,
    this.refreshToken,
  });

  /// Create AuthResponseModel from JSON
  factory AuthResponseModel.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseModelFromJson(json);

  /// Convert AuthResponseModel to JSON
  Map<String, dynamic> toJson() => _$AuthResponseModelToJson(this);

  /// User model from the response
  final UserModel user;

  /// Authentication token from the response
  final String token;

  /// Refresh token from the response (optional)
  final String? refreshToken;
}
