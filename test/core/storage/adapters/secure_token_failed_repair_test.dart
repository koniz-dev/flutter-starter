// A token write that outlives the store's wait bound and lands after a clear
// is undone by a repair. That repair used to be dropped silently when its own
// platform call failed, leaving a token at rest after a logout that reported
// success. It is now retried, then left stale for the next write or delete to
// re-apply, and reported to the logger by key, never by value.

import 'dart:async';

import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/storage/adapters/secure_token_store.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements SecureStorageService {}

class _MockLogger extends Mock implements LoggingService {}

const _bound = Duration(milliseconds: 50);
const _token = 'live-access-token-value';
const String _key = AppConstants.tokenKey;

/// A backing store over [values]. The write of [_token] completes only when
/// [slowWrite] does; [removeResults] answers the deletes in order, then true.
class _Backing {
  _Backing() {
    when(() => storage.setString(any(), any())).thenAnswer((i) async {
      final value = i.positionalArguments[1] as String;
      if (value == _token) await slowWrite.future;
      values[i.positionalArguments[0] as String] = value;
      return true;
    });
    when(() => storage.remove(any())).thenAnswer((i) async {
      final key = i.positionalArguments[0] as String;
      if (key == _key) removes++;
      final ok = removeResults.isEmpty || removeResults.removeAt(0);
      if (ok) values.remove(key);
      return ok;
    });
  }

  final storage = _MockSecureStorage();
  final values = <String, String>{};
  final slowWrite = Completer<void>();
  final removeResults = <bool>[];
  int removes = 0;
}

Future<void> _settle() => Future<void>.delayed(_bound * 6);

/// Lands [_token] after a successful clear of [_key], so a repair is due.
Future<void> _lateWriteOverClear(
  _Backing backing,
  SecureTokenStore store,
) async {
  final write = store.setAccessToken(_token);
  await store.clearAccessToken(); // runs after the bound, succeeds
  expect(backing.values, isEmpty);
  backing.slowWrite.complete();
  await write;
}

void main() {
  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  test('a repair whose first attempt fails is retried and lands', () async {
    final backing = _Backing();
    final store = SecureTokenStore(backing.storage, operationTimeout: _bound);

    // The clear succeeds; the repair's first delete fails, its second works.
    backing.removeResults.addAll([true, false]);
    await _lateWriteOverClear(backing, store);
    await _settle();

    expect(backing.values, isEmpty);
  });

  test('a repair that keeps failing stops after a bounded number of '
      'attempts, and the next write or delete re-applies it', () async {
    final backing = _Backing();
    final store = SecureTokenStore(backing.storage, operationTimeout: _bound);

    backing.removeResults.addAll([
      true, // the clear
      ...List.filled(SecureTokenStore.repairAttempts, false),
    ]);
    await _lateWriteOverClear(backing, store);
    await _settle();

    expect(backing.removes, 1 + SecureTokenStore.repairAttempts);
    expect(backing.values[_key], _token, reason: 'the repair could not land');

    await _settle();
    expect(
      backing.removes,
      1 + SecureTokenStore.repairAttempts,
      reason: 'no retry loop',
    );

    // The next operation on the service, on another key, re-applies it.
    await store.setRefreshToken('r');
    expect(backing.values.containsKey(_key), isFalse);
    expect(backing.values[AppConstants.refreshTokenKey], 'r');
  });

  test('clearAllTokens re-applies a stale key', () async {
    final backing = _Backing();
    final store = SecureTokenStore(backing.storage, operationTimeout: _bound);

    backing.removeResults.addAll([
      true,
      ...List.filled(SecureTokenStore.repairAttempts, false),
    ]);
    await _lateWriteOverClear(backing, store);
    await _settle();
    expect(backing.values[_key], _token);

    await store.clearAllTokens();

    expect(backing.values, isEmpty);
  });

  test('a failed repair is logged as a warning naming the key, never the '
      'value', () async {
    final backing = _Backing();
    final logger = _MockLogger();
    final store = SecureTokenStore(
      backing.storage,
      operationTimeout: _bound,
      logger: logger,
    );

    backing.removeResults.addAll([
      true,
      ...List.filled(SecureTokenStore.repairAttempts, false),
    ]);
    await _lateWriteOverClear(backing, store);
    await _settle();

    final captured = verify(
      () => logger.warning(
        captureAny(),
        context: captureAny(named: 'context'),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
      ),
    ).captured;
    expect(captured, hasLength(2), reason: 'one warning: message, context');
    final logged = '${captured[0]} ${captured[1]}';
    expect(logged, contains(_key));
    expect(logged, isNot(contains(_token)));
    verifyNever(
      () => logger.error(
        any(),
        context: any(named: 'context'),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
      ),
    );
  });
}
