import 'package:flutter_starter/features/auth/data/models/user_model.dart';

/// Authentication response model containing user and token
class AuthResponseModel {
  /// Creates an [AuthResponseModel] with [user], [token], and optional
  /// [refreshToken]
  const AuthResponseModel({
    required this.user,
    required this.token,
    this.refreshToken,
  });

  /// Create AuthResponseModel from JSON
  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      token: json['token'] as String,
      refreshToken: json['refresh_token'] as String?,
    );
  }

  /// User model from the response
  final UserModel user;

  /// Authentication token from the response
  final String token;

  /// Refresh token from the response (optional)
  final String? refreshToken;
}
