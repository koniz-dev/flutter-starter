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
/// Each read, write and delete waits for the ones issued before it to settle,
/// up to a bound (below).
/// The session guards in `AuthRepositoryImpl.refreshToken()` and
/// `AuthInterceptor` check the session immediately before a write, which only
/// helps if a logout's clear, issued after that check, also *lands* after the
/// write. flutter_secure_storage does not promise that on every platform: on
/// web, a write awaits WebCrypto encryption before it reaches `localStorage`,
/// while a delete removes the key at once, so a clear issued after a pending
/// write ran before it and the write then re-stored a token on a signed-out
/// browser. Queuing here makes the order the code issues the order the store
/// applies, on every platform, without clearing anything a newer session
/// wrote - except for a call that outlives the bound, which the repair below
/// covers.
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
/// call stays hung only for its own caller.
///
/// A call that outlives the bound and then succeeds lands after operations
/// issued later. For a write or delete, that would leave the older state on
/// the device - a refresh's token write landing after a logout's clear would
/// re-store a credential on a signed-out device. So each write and delete is
/// numbered when it is issued, and one that lands after a newer write or
/// delete of the same key has landed is followed by a repair that puts the
/// newer state back, queued like any other operation. Between the late
/// landing and the repair the older value is briefly at rest. A repair that
/// fails is retried, up to three attempts; if every attempt fails, the key is
/// marked stale and a warning naming the key (never its value) goes to the
/// logger. Until it is re-applied, a read of a stale key answers from memory
/// with the newer state - `null` after a clear - never with the late value
/// on the device. The next write through any store over the same service
/// re-applies every stale key first; the next delete re-applies only stale
/// deletes, so a sign-out never writes a token. A read of a stale key whose
/// newer state is a delete retries that delete, bounded like any operation
/// and one retry per key at a time; a read never writes. Once everything
/// settles and no repair has failed, every key holds what its last-issued
/// successful write or delete left. The stale marker lives in memory: if the
/// app stops before a stale key is re-applied, the late value is what the
/// next launch reads.
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
  Future<bool> setAccessToken(String token) =>
      _mutate(AppConstants.tokenKey, token);

  /// Throws [CacheException] if the Keychain/Keystore delete fails.
  @override
  Future<void> clearAccessToken() => _remove(AppConstants.tokenKey);

  /// Throws [CacheException] if the Keychain/Keystore read fails; see
  /// [getAccessToken].
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
      // A cleared key still holding a late token: try the delete once more,
      // so a signed-out app that never writes or deletes again does not leave
      // that token for the next launch to read. Never a write: a read must
      // not store a credential. Bounded, and a failure leaves the key stale.
      // One retry per key at a time: while a hung delete is pending, a read
      // answers from memory at once instead of waiting a bound of its own
      // and leaving another delete behind it.
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

  /// [SecureStorageService.remove] reports a failed delete as `false` rather
  /// than throwing. Ignoring that bool made a failed delete invisible.
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
        'undone; reads of it answer from memory until the next write, or the '
        'next delete of that key, re-applies it',
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
