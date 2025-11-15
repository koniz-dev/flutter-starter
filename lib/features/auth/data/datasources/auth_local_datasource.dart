import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/utils/json_helper.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';

/// Local data source for authentication
abstract class AuthLocalDataSource {
  /// Caches a [user] to local storage
  Future<void> cacheUser(UserModel user);

  /// Retrieves cached user from local storage
  Future<UserModel?> getCachedUser();

  /// Caches an authentication [token] to local storage
  Future<void> cacheToken(String token);

  /// Retrieves cached authentication token from local storage
  Future<String?> getToken();

  /// Caches a refresh [token] to local storage
  Future<void> cacheRefreshToken(String token);

  /// Retrieves cached refresh token from local storage
  Future<String?> getRefreshToken();

  /// Clears all cached authentication data
  Future<void> clearCache();
}

/// Implementation of local data source
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  /// Creates an [AuthLocalDataSourceImpl] with the given [storageService]
  AuthLocalDataSourceImpl(this.storageService);

  /// Storage service for persisting data
  final StorageService storageService;

  @override
  Future<void> cacheUser(UserModel user) async {
    try {
      final userJson = JsonHelper.encode(user.toJson());
      if (userJson == null) {
        throw const CacheException('Failed to encode user data');
      }
      await storageService.setString(AppConstants.userDataKey, userJson);
    } on Exception catch (e) {
      throw CacheException('Failed to cache user: $e');
    }
  }

  @override
  Future<UserModel?> getCachedUser() async {
    try {
      final userJson = await storageService.getString(AppConstants.userDataKey);
      if (userJson == null) return null;

      final userMap = JsonHelper.decodeMap(userJson);
      if (userMap == null) {
        throw const CacheException('Failed to decode user data');
      }
      return UserModel.fromJson(userMap);
    } on Exception catch (e) {
      throw CacheException('Failed to get cached user: $e');
    }
  }

  @override
  Future<void> cacheToken(String token) async {
    try {
      await storageService.setString(AppConstants.tokenKey, token);
    } on Exception catch (e) {
      throw CacheException('Failed to cache token: $e');
    }
  }

  @override
  Future<String?> getToken() async {
    try {
      return await storageService.getString(AppConstants.tokenKey);
    } on Exception catch (e) {
      throw CacheException('Failed to get token: $e');
    }
  }

  @override
  Future<void> cacheRefreshToken(String token) async {
    try {
      await storageService.setString(AppConstants.refreshTokenKey, token);
    } on Exception catch (e) {
      throw CacheException('Failed to cache refresh token: $e');
    }
  }

  @override
  Future<String?> getRefreshToken() async {
    try {
      return await storageService.getString(AppConstants.refreshTokenKey);
    } on Exception catch (e) {
      throw CacheException('Failed to get refresh token: $e');
    }
  }

  @override
  Future<void> clearCache() async {
    try {
      await storageService.remove(AppConstants.userDataKey);
      await storageService.remove(AppConstants.tokenKey);
      await storageService.remove(AppConstants.refreshTokenKey);
    } on Exception catch (e) {
      throw CacheException('Failed to clear cache: $e');
    }
  }
}
