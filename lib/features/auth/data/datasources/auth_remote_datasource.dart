import 'package:flutter_starter/core/constants/api_endpoints.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';

/// Remote data source for authentication
abstract class AuthRemoteDataSource {
  /// Authenticates user with [email] and [password]
  Future<UserModel> login(String email, String password);

  /// Registers a new user with [email], [password], and [name]
  Future<UserModel> register(String email, String password, String name);

  /// Logs out the current user
  Future<void> logout();
}

/// Implementation of remote data source
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  /// Creates an [AuthRemoteDataSourceImpl] with the given [apiClient]
  AuthRemoteDataSourceImpl(this.apiClient);

  /// API client for making HTTP requests
  final ApiClient apiClient;

  @override
  Future<UserModel> login(String email, String password) async {
    try {
      final response = await apiClient.post(
        ApiEndpoints.login,
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return UserModel.fromJson(
          data['user'] as Map<String, dynamic>,
        );
      } else {
        final data = response.data as Map<String, dynamic>;
        throw ServerException(
          (data['message'] as String?) ?? 'Login failed',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to login: $e');
    }
  }

  @override
  Future<UserModel> register(
    String email,
    String password,
    String name,
  ) async {
    try {
      final response = await apiClient.post(
        ApiEndpoints.register,
        data: {
          'email': email,
          'password': password,
          'name': name,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        return UserModel.fromJson(
          data['user'] as Map<String, dynamic>,
        );
      } else {
        final data = response.data as Map<String, dynamic>;
        throw ServerException(
          (data['message'] as String?) ?? 'Registration failed',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to register: $e');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await apiClient.post(ApiEndpoints.logout);
    } catch (e) {
      throw ServerException('Failed to logout: $e');
    }
  }
}
