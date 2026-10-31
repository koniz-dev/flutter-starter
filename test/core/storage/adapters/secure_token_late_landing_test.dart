// An operation waits for the one ahead of it only up to operationTimeout, so
// a platform call that outlives the bound and then succeeds lands after
// operations issued later. A token write landing after a logout's clear
// re-stored a credential on a signed-out device. The store now puts back the
// newer state when that happens.

import 'dart:async';

import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/storage/adapters/secure_token_store.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements SecureStorageService {}

const _bound = Duration(milliseconds: 50);

/// A backing store over [values] whose writes and deletes complete only when
/// the test completes the matching gate; ungated calls complete at once.
class _Backing {
  _Backing() {
    when(() => storage.setString(any(), any())).thenAnswer((i) async {
      final key = i.positionalArguments[0] as String;
      final value = i.positionalArguments[1] as String;
      final gate = writeGates.remove(value);
      if (gate != null) await gate.future;
      values[key] = value;
      return true;
    });
    when(() => storage.remove(any())).thenAnswer((i) async {
      final key = i.positionalArguments[0] as String;
      final gate = deleteGates.remove(key);
      if (gate != null) await gate.future;
      values.remove(key);
      return true;
    });
    when(() => storage.getStringOrThrow(any())).thenAnswer(
      (i) async => values[i.positionalArguments[0] as String],
    );
  }

  final storage = _MockSecureStorage();
  final values = <String, String>{};

  /// Gates on writes, by the value written.
  final writeGates = <String, Completer<void>>{};

  /// Gates on deletes, by key.
  final deleteGates = <String, Completer<void>>{};
}

Future<void> _settle() => Future<void>.delayed(_bound * 4);

void main() {
  test(
    'a write that lands after the bound and after a clear is undone',
    () async {
      final backing = _Backing();
      final store = SecureTokenStore(backing.storage, operationTimeout: _bound);
      final slowWrite = backing.writeGates['refreshed'] = Completer<void>();

      final write = store.setAccessToken('refreshed');
      await store.clearAllTokens(); // runs after the bound
      expect(backing.values, isEmpty);

      slowWrite.complete(); // the stalled platform call finally succeeds
      expect(await write, isTrue);
      await _settle();

      expect(
        backing.values,
        isEmpty,
        reason: 'no token may be at rest after the clear',
      );
    },
  );

  test(
    'a delete that lands after a newer write puts the newer token back',
    () async {
      final backing = _Backing();
      final store = SecureTokenStore(backing.storage, operationTimeout: _bound);
      backing.values[AppConstants.tokenKey] = 'old';
      final slowDelete = backing.deleteGates[AppConstants.tokenKey] =
          Completer<void>();

      final clear = store.clearAccessToken();
      await store.setAccessToken('signed-in-again'); // runs after the bound
      expect(backing.values[AppConstants.tokenKey], 'signed-in-again');

      slowDelete.complete();
      await clear;
      await _settle();

      expect(backing.values[AppConstants.tokenKey], 'signed-in-again');
    },
  );

  test(
    'a late write overtaken by a newer write leaves the newer value',
    () async {
      final backing = _Backing();
      final store = SecureTokenStore(backing.storage, operationTimeout: _bound);
      final slowWrite = backing.writeGates['first'] = Completer<void>();

      final first = store.setAccessToken('first');
      await store.setAccessToken('second');

      slowWrite.complete();
      await first;
      await _settle();

      expect(backing.values[AppConstants.tokenKey], 'second');
    },
  );

  test('a late write that nothing overtook on its key stays', () async {
    final backing = _Backing();
    final store = SecureTokenStore(backing.storage, operationTimeout: _bound);
    final slowWrite = backing.writeGates['refreshed'] = Completer<void>();

    final write = store.setAccessToken('refreshed');
    await store.setRefreshToken('r'); // a different key

    slowWrite.complete();
    await write;
    await _settle();

    expect(backing.values, {
      AppConstants.tokenKey: 'refreshed',
      AppConstants.refreshTokenKey: 'r',
    });
  });
}
