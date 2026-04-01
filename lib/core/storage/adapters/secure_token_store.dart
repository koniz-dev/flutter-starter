import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';

/// Secure token store implementation backed by [SecureStorageService].
class SecureTokenStore implements ITokenStore {
  /// Creates a token store backed by secure platform storage.
  SecureTokenStore(this._secureStorageService);

  final SecureStorageService _secureStorageService;

  @override
  Future<String?> getAccessToken() {
    return _secureStorageService.getString(AppConstants.tokenKey);
  }

  @override
  Future<bool> setAccessToken(String token) async {
    return _secureStorageService.setString(AppConstants.tokenKey, token);
  }

  @override
  Future<void> clearAccessToken() async {
    await _secureStorageService.remove(AppConstants.tokenKey);
  }

  @override
  Future<String?> getRefreshToken() {
    return _secureStorageService.getString(AppConstants.refreshTokenKey);
  }

  @override
  Future<bool> setRefreshToken(String token) async {
    return _secureStorageService.setString(AppConstants.refreshTokenKey, token);
  }

  @override
  Future<void> clearRefreshToken() async {
    await _secureStorageService.remove(AppConstants.refreshTokenKey);
  }

  @override
  Future<void> clearAllTokens() async {
    await clearAccessToken();
    await clearRefreshToken();
  }
}
