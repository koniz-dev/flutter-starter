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
/// The queue belongs to the [SecureStorageService] underneath, not to this
/// object: every `SecureTokenStore` built over the same service shares it.
/// It used to be a field of each store, so the store `AuthInterceptor` builds
/// for itself from `secureStorageService:` and the one the repository uses
/// ordered their own calls but not each other's - and a logout's clear on one
/// could again land before a refresh write on the other. Two stores over two
/// different `SecureStorageService` objects still do not share a queue, so the
/// app builds one service (`secureStorageServiceProvider`).
///
/// The wait is bounded by [operationTimeout] (10 seconds by default).
/// Without the bound, one platform call that never completed held every later
/// token operation behind it - the token read on each request and a logout's
/// clear included - until the app was restarted. Now an operation queued
/// behind one that has not settled within the bound runs anyway; the hung
/// call stays hung only for its own caller. The residual: if that call later
/// completes, it lands out of order - which needs a call to hang for the whole
/// bound and then succeed, where before any hang wedged the app.
class SecureTokenStore implements ITokenStore {
  /// Creates a token store backed by secure platform storage.
  SecureTokenStore(
    this._secureStorageService, {
    this.operationTimeout = const Duration(seconds: 10),
  });

  final SecureStorageService _secureStorageService;

  /// How long an operation waits for the one queued ahead of it before it
  /// runs anyway.
  final Duration operationTimeout;

  /// The operation queue of each backing service, shared by every store over
  /// it.
  static final Expando<_OperationQueue> _queues = Expando<_OperationQueue>(
    'SecureTokenStore operation queue',
  );

  _OperationQueue get _queue =>
      _queues[_secureStorageService] ??= _OperationQueue();

  /// Runs [operation] once every operation issued before it, through any
  /// store over the same service, has settled. A failed operation does not
  /// wedge the queue.
  Future<T> _inOrder<T>(Future<T> Function() operation) {
    final queue = _queue;
    final previous = queue.tail;
    final done = Completer<void>();
    queue.tail = done.future;
    Future<T> run() async {
      try {
        // Bounded: a predecessor that never settles - a hung platform call -
        // stops holding this operation after [operationTimeout]. The bound is
        // on the wait, not on the platform call, so an operation with nothing
        // queued ahead of it starts no timer.
        if (previous != null) {
          await previous.timeout(operationTimeout, onTimeout: () {});
        }
        return await operation();
      } finally {
        done.complete();
        if (identical(queue.tail, done.future)) queue.tail = null;
      }
    }

    return run();
  }

  /// Throws [CacheException] if the Keychain/Keystore read fails.
  ///
  /// [SecureStorageService.getString] answers a failed read with `null`, the
  /// same as a missing token, so a transient failure (an iOS Keychain read
  /// before first unlock) sent a request unauthenticated, its 401 found "no
  /// refresh token", and the user was signed out. The strict read tells the
  /// two apart: the caller fails the one request and keeps the session.
  @override
  Future<String?> getAccessToken() =>
      _inOrder(() => _read(AppConstants.tokenKey));

  @override
  Future<bool> setAccessToken(String token) => _inOrder(
    () => _secureStorageService.setString(AppConstants.tokenKey, token),
  );

  /// Throws [CacheException] if the Keychain/Keystore delete fails.
  @override
  Future<void> clearAccessToken() =>
      _inOrder(() => _remove(AppConstants.tokenKey));

  /// Throws [CacheException] if the Keychain/Keystore read fails; see
  /// [getAccessToken].
  @override
  Future<String?> getRefreshToken() =>
      _inOrder(() => _read(AppConstants.refreshTokenKey));

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

  Future<String?> _read(String key) async {
    try {
      return await _secureStorageService.getStringOrThrow(key);
    } on Exception catch (e) {
      throw CacheException('Failed to read $key from secure storage: $e');
    }
  }

  /// [SecureStorageService.remove] reports a failed delete as `false` rather
  /// than throwing. Ignoring that bool made a failed delete invisible.
  Future<void> _remove(String key) async {
    if (!await _secureStorageService.remove(key)) {
      throw CacheException('Failed to delete $key from secure storage');
    }
  }
}

/// Tail of one backing service's operation queue; null while idle.
class _OperationQueue {
  Future<void>? tail;
}
