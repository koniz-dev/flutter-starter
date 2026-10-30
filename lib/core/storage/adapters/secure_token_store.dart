import 'dart:async';

import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';

/// Secure token store implementation backed by [SecureStorageService].
///
/// ## Every operation runs in the order it was issued
///
/// Each read, write and delete waits for the ones issued before it to settle.
/// The session guards in `AuthRepositoryImpl.refreshToken()` and
/// `AuthInterceptor` check the session immediately before a write, which only
/// helps if a logout's clear, issued after that check, also *lands* after the
/// write. flutter_secure_storage does not promise that on every platform: on
/// web, a write awaits WebCrypto encryption before it reaches `localStorage`,
/// while a delete removes the key at once, so a clear issued after a pending
/// write ran before it and the write then re-stored a token on a signed-out
/// browser. Queuing here makes the order the code issues the order the store
/// applies, on every platform, without clearing anything a newer session
/// wrote.
///
/// The cost: one platform call that never completes holds every later token
/// operation behind it, the token read on each request and a logout's clear
/// included. Keychain and Keystore failures surface as errors, which do not
/// hold the queue; a call that hangs outright would.
class SecureTokenStore implements ITokenStore {
  /// Creates a token store backed by secure platform storage.
  SecureTokenStore(this._secureStorageService);

  final SecureStorageService _secureStorageService;

  /// Tail of the operation queue; null while idle.
  Future<void>? _queue;

  /// Runs [operation] once every operation issued before it has settled. A
  /// failed operation does not wedge the queue.
  Future<T> _inOrder<T>(Future<T> Function() operation) {
    final previous = _queue;
    final done = Completer<void>();
    _queue = done.future;
    Future<T> run() async {
      try {
        if (previous != null) await previous;
        return await operation();
      } finally {
        done.complete();
        if (identical(_queue, done.future)) _queue = null;
      }
    }

    return run();
  }

  @override
  Future<String?> getAccessToken() => _inOrder(
    () => _secureStorageService.getString(AppConstants.tokenKey),
  );

  @override
  Future<bool> setAccessToken(String token) => _inOrder(
    () => _secureStorageService.setString(AppConstants.tokenKey, token),
  );

  /// Throws [CacheException] if the Keychain/Keystore delete fails.
  @override
  Future<void> clearAccessToken() =>
      _inOrder(() => _remove(AppConstants.tokenKey));

  @override
  Future<String?> getRefreshToken() => _inOrder(
    () => _secureStorageService.getString(AppConstants.refreshTokenKey),
  );

  @override
  Future<bool> setRefreshToken(String token) => _inOrder(
    () => _secureStorageService.setString(
      AppConstants.refreshTokenKey,
      token,
    ),
  );

  /// Throws [CacheException] if the Keychain/Keystore delete fails.
  @override
  Future<void> clearRefreshToken() =>
      _inOrder(() => _remove(AppConstants.refreshTokenKey));

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
