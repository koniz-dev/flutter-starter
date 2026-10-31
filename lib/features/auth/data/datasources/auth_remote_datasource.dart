import 'package:flutter_starter/core/constants/api_endpoints.dart';
import 'package:flutter_starter/core/contracts/network_contracts.dart';
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/features/auth/data/models/auth_response_model.dart';

/// Remote data source for authentication
abstract class AuthRemoteDataSource {
  /// Authenticates user with [email] and [password]
  Future<AuthResponseModel> login(String email, String password);

  /// Registers a new user with [email], [password], and [name]
  Future<AuthResponseModel> register(
    String email,
    String password,
    String name,
  );

  /// Logs out the current user
  Future<void> logout({String? refreshToken});

  /// Refreshes the authentication token using [refreshToken]
  Future<AuthResponseModel> refreshToken(String refreshToken);
}

/// Implementation of remote data source
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  /// Creates an [AuthRemoteDataSourceImpl] using the shared [ApiClient] (Dio +
  /// interceptors). To use a different transport, rebind the auth remote data
  /// source in `lib/features/auth/di/auth_providers.dart` with your own
  /// [AuthRemoteDataSource] implementation.
  AuthRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<AuthResponseModel> login(String email, String password) async {
    // Error interceptor handles DioException conversion automatically
    // Dio throws for non-2xx status codes, so we don't need status code checks
    final response = await _post(ApiEndpoints.login, <String, dynamic>{
      'email': email,
      'password': password,
    });

    final data = response.data as Map<String, dynamic>;
    return AuthResponseModel.fromJson(data);
  }

  @override
  Future<AuthResponseModel> register(
    String email,
    String password,
    String name,
  ) async {
    // Error interceptor handles DioException conversion automatically
    // Dio throws for non-2xx status codes, so we don't need status code checks
    final response = await _post(ApiEndpoints.register, <String, dynamic>{
      'email': email,
      'password': password,
      'name': name,
    });

    final data = response.data as Map<String, dynamic>;
    return AuthResponseModel.fromJson(data);
  }

  /// Posts [refreshToken] as `refresh_token` - the same field the refresh
  /// call sends - so the server can revoke it. Without it the server could
  /// not tell which refresh token to revoke, and one copied earlier stayed
  /// valid after sign-out. `ApiLoggingInterceptor` redacts the field.
  @override
  Future<void> logout({String? refreshToken}) async {
    // Error interceptor handles DioException conversion automatically
    await _post(
      ApiEndpoints.logout,
      refreshToken == null
          ? null
          : <String, dynamic>{'refresh_token': refreshToken},
    );
  }

  @override
  Future<AuthResponseModel> refreshToken(String refreshToken) async {
    // Error interceptor handles DioException conversion automatically
    // Dio throws for non-2xx status codes, so we don't need status code checks
    final response = await _post(ApiEndpoints.refreshToken, <String, dynamic>{
      'refresh_token': refreshToken,
    });

    final data = response.data as Map<String, dynamic>;
    return AuthResponseModel.fromJson(data);
  }

  /// Typed on [NetworkResponse], the transport-agnostic contract, so no dio
  /// type reaches this feature and the transport stays swappable.
  Future<NetworkResponse<dynamic>> _post(
    String path,
    Map<String, dynamic>? body,
  ) {
    return _apiClient.post(path, data: body);
  }
}
