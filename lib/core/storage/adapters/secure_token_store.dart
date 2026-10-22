import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
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

  /// Throws [CacheException] if the Keychain/Keystore delete fails.
  @override
  Future<void> clearAccessToken() => _remove(AppConstants.tokenKey);

  @override
  Future<String?> getRefreshToken() {
    return _secureStorageService.getString(AppConstants.refreshTokenKey);
  }

  @override
  Future<bool> setRefreshToken(String token) async {
    return _secureStorageService.setString(AppConstants.refreshTokenKey, token);
  }

  /// Throws [CacheException] if the Keychain/Keystore delete fails.
  @override
  Future<void> clearRefreshToken() => _remove(AppConstants.refreshTokenKey);

  /// Deletes both tokens, attempting the second even when the first fails.
  ///
  /// Throws [CacheException] if either delete failed: a token that is still
  /// on the device after a logout must reach the caller, not read as success.
  @override
  Future<void> clearAllTokens() async {
    (Object, StackTrace)? first;
    for (final clear in [clearAccessToken, clearRefreshToken]) {
      try {
        await clear();
      } on Object catch (e, stack) {
        first ??= (e, stack);
      }
    }
    if (first != null) Error.throwWithStackTrace(first.$1, first.$2);
  }

  /// [SecureStorageService.remove] reports a failed delete as `false` rather
  /// than throwing. Ignoring that bool made a failed delete invisible.
  Future<void> _remove(String key) async {
    if (!await _secureStorageService.remove(key)) {
      throw CacheException('Failed to delete $key from secure storage');
    }
  }
}
