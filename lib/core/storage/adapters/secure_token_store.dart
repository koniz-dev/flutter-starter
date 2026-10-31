import 'dart:async';

import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';

/// Secure token store implementation backed by [SecureStorageService].
///
/// ## Operations take effect in the order they were issued
///
/// Each read, write and delete waits for the ones issued before it, so a
/// logout's clear issued after a refresh's write also lands after it. The
/// session guards in `AuthRepositoryImpl.refreshToken()` and `AuthInterceptor`
/// rely on that; flutter_secure_storage does not promise it on every platform
/// (on web a write awaits encryption while a delete is immediate).
///
/// The queue belongs to the [SecureStorageService], so every store over the
/// same service shares it. Stores over different services do not: build one
/// service (`secureStorageServiceProvider`).
///
/// The wait is bounded by [operationTimeout] (10 seconds by default), so one
/// hung platform call does not hold every later token operation.
///
/// ## A call that outlives the bound
///
/// It may land after operations issued later. Writes and deletes are numbered
/// when issued, and one that lands over a newer one of the same key is
/// followed by a repair that puts the newer state back (the older value is at
/// rest in between). A repair is tried [repairAttempts] times; if all fail,
/// the key is marked stale and the logger is warned, naming the key, never the
/// value. A stale key reads from memory - the newer state, `null` after a
/// clear - and is re-applied by the next write through the service, or, if
/// its newer state is a delete, by the next delete or a read of it. A read
/// never writes. The stale marker is in memory: if the app stops first, the
/// next launch reads the late value.
///
/// A read that outlived the bound returns what the store held when it ran.
class SecureTokenStore implements ITokenStore {
  /// Creates a token store backed by secure platform storage.
  ///
  /// [logger] receives the warning for a repair that could not land. Stores
  /// over the same service share it, so one store given a logger is enough.
  SecureTokenStore(
    this._secureStorageService, {
    this.operationTimeout = const Duration(seconds: 10),
    LoggingService? logger,
  }) {
    if (logger != null) _queue.logger ??= logger;
  }

  /// How many times a repair is attempted before its key is left stale.
  static const repairAttempts = 3;

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

  /// Throws [CacheException] if the Keychain/Keystore read fails, rather
  /// than answering `null` as for a missing token: an ordinary request then
  /// fails and the session is kept (an iOS Keychain read before first unlock,
  /// say).
  ///
  /// A failed read during a 401 refresh ends the session: the refresh fails
  /// with a `CacheFailure`, and `AuthInterceptor` fails closed on any refresh
  /// failure that is not transport trouble.
  @override
  Future<String?> getAccessToken() =>
      _inOrder(() => _read(AppConstants.tokenKey));

  @override
  Future<bool> setAccessToken(String token) =>
      _mutate(AppConstants.tokenKey, token);

  /// Throws [CacheException] if the Keychain/Keystore delete fails.
  @override
  Future<void> clearAccessToken() => _remove(AppConstants.tokenKey);

  /// Throws [CacheException] if the Keychain/Keystore read fails. It is read
  /// only to refresh after a 401 (and to revoke it at logout), so a failure
  /// here ends the session; see [getAccessToken].
  @override
  Future<String?> getRefreshToken() =>
      _inOrder(() => _read(AppConstants.refreshTokenKey));

  @override
  Future<bool> setRefreshToken(String token) =>
      _mutate(AppConstants.refreshTokenKey, token);

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

  Future<String?> _read(String key) async {
    // The device holds a late value a failed repair could not undo; memory
    // holds what the last-issued successful write or delete left.
    final queue = _queue;
    if (queue.stale.contains(key)) {
      final newest = queue.landed[key]!;
      // A cleared key still holding a late token: retry the delete, so a
      // signed-out app does not leave it for the next launch. Bounded, one
      // retry per key at a time, and never a write.
      if (newest.value == null && !queue.retryingDeletes.containsKey(key)) {
        final attempt = _apply(
          queue,
          key,
          newest.number,
          null,
          flushStale: false,
        );
        queue.retryingDeletes[key] = attempt;
        unawaited(
          attempt
              .then<void>((_) {}, onError: (Object _) {})
              .whenComplete(
                () => queue.retryingDeletes.removeWhere(
                  (k, pending) => k == key && identical(pending, attempt),
                ),
              ),
        );
        try {
          await attempt.timeout(operationTimeout);
        } on Object {
          // Still stale; memory still answers.
        }
      }
      return newest.value;
    }
    try {
      return await _secureStorageService.getStringOrThrow(key);
    } on Exception catch (e) {
      throw CacheException('Failed to read $key from secure storage: $e');
    }
  }

  /// [SecureStorageService.remove] reports a failed delete as `false`; this
  /// turns it into a [CacheException], so the caller knows the token may
  /// remain.
  Future<void> _remove(String key) async {
    if (!await _mutate(key, null)) {
      throw CacheException('Failed to delete $key from secure storage');
    }
  }

  /// Writes [value] to [key], or deletes [key] when [value] is null, in
  /// order. Returns whether the platform call succeeded.
  Future<bool> _mutate(String key, String? value) {
    final queue = _queue;
    final number = ++queue.issued;
    return _inOrder(() => _apply(queue, key, number, value));
  }

  /// Applies one write ([value] non-null) or delete of [key], numbered
  /// [number]. Unless [flushStale] is false, first re-applies the newest
  /// state of every other key a failed repair left stale.
  Future<bool> _apply(
    _OperationQueue queue,
    String key,
    int number,
    String? value, {
    bool flushStale = true,
  }) async {
    if (flushStale) {
      for (final stale in queue.stale.where((k) => k != key).toList()) {
        final newest = queue.landed[stale]!;
        // A delete re-applies only deletes: re-writing a token from inside a
        // sign-out's clear could land after it.
        if (value == null && newest.value != null) continue;
        try {
          // Bounded like the queue's own wait, so a hung platform call here
          // holds this operation no longer than one queued ahead of it would.
          await _apply(
            queue,
            stale,
            newest.number,
            newest.value,
            flushStale: false,
          ).timeout(operationTimeout);
        } on Object {
          // Still stale; the next write or delete tries again.
        }
      }
    }
    final succeeded = value == null
        ? await _secureStorageService.remove(key)
        : await _secureStorageService.setString(key, value);
    if (!succeeded) return false;
    final newest = queue.landed[key];
    if (newest == null || newest.number <= number) {
      queue.landed[key] = (number: number, value: value);
      queue.stale.remove(key);
    } else {
      // This call outlived the wait and landed over a newer one.
      unawaited(_repair(queue, key));
    }
    return true;
  }

  /// Re-applies the newest landed state of [key], up to [repairAttempts]
  /// times. Runs in the queue, so it reads that state when its turn comes; a
  /// repair overtaken in turn is repaired again by [_apply]. When every
  /// attempt fails, [key] is left stale for the next write or delete to
  /// re-apply, and the logger is warned: there is no caller to report to.
  Future<void> _repair(_OperationQueue queue, String key) async {
    final target = queue.landed[key]!.number;
    Object? lastError;
    for (var attempt = 0; attempt < repairAttempts; attempt++) {
      try {
        final repaired = await _inOrder(() {
          final newest = queue.landed[key]!;
          return _apply(
            queue,
            key,
            newest.number,
            newest.value,
            flushStale: false,
          );
        });
        if (repaired) return;
      } on Object catch (e) {
        lastError = e;
      }
    }
    // A newer write or delete of this key that landed meanwhile already put
    // the device in step with memory.
    if (queue.landed[key]!.number != target) return;
    queue.stale.add(key);
    try {
      queue.logger?.warning(
        'Secure token store: a late write or delete of $key could not be '
        'undone; reads of it answer from memory until it is re-applied - by '
        'the next write through this service, or, if its newer state is a '
        'delete, by the next delete or the next read of it',
        context: {
          'key': key,
          'attempts': repairAttempts,
          if (lastError != null) 'error': lastError.runtimeType.toString(),
        },
      );
    } on Object {
      // Nothing to report to: this runs unawaited.
    }
  }
}

/// One backing service's operation queue.
class _OperationQueue {
  /// Tail of the queue; null while idle.
  Future<void>? tail;

  /// How many writes and deletes have been issued; numbers each one.
  int issued = 0;

  /// The newest write or delete that has landed, per key: its number and
  /// the value it left, null for a delete.
  final Map<String, ({int number, String? value})> landed = {};

  /// Keys whose repair failed: what is stored may be older than [landed].
  final Set<String> stale = {};

  /// A stale delete a read is retrying, per key, until its platform call
  /// settles.
  final Map<String, Future<bool>> retryingDeletes = {};

  /// Where a failed repair is reported; set by the first store given one.
  LoggingService? logger;
}
