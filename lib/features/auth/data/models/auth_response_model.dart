import 'package:flutter_starter/features/auth/data/models/user_model.dart';
import 'package:json_annotation/json_annotation.dart';

part 'auth_response_model.g.dart';

/// Authentication response model containing user and token
///
/// The auth slice speaks snake_case on the wire, both ways: the refresh
/// request sends `refresh_token`, [UserModel] reads `avatar_url`, and this
/// model reads `user`, `token` and `refresh_token`. A backend that answered
/// `refreshToken` while the app sent `refresh_token` used to have its refresh
/// token parsed as null and never stored, so the first expiry forced a logout.
@JsonSerializable(explicitToJson: true)
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

  /// Refresh token from the response (optional), wire key `refresh_token`
  @JsonKey(name: 'refresh_token')
  final String? refreshToken;
}
