// When a repair of a late-landed token write fails every attempt, the key is
// left stale: the device holds the late value. Reads used to return it, so a
// signed-out app kept sending that token. And the flush that re-applies stale
// keys could write a refresh token from inside a sign-out's clear.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/network/interceptors/auth_interceptor.dart';
import 'package:flutter_starter/core/storage/adapters/secure_token_store.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements SecureStorageService {}

const _bound = Duration(milliseconds: 50);
const _late = 'late-landed-token';

/// A backing store over [values]: a write of [_late] or a delete of a key in
/// [slowDeletes] waits for [gate]; [failRemove] and [failSet] make the
/// matching calls report failure once [gate] has completed.
class _Backing {
  _Backing() {
    when(() => storage.setString(any(), any())).thenAnswer((i) async {
      final key = i.positionalArguments[0] as String;
      final value = i.positionalArguments[1] as String;
      writes.add(key);
      if (value == _late) await gate.future;
      if (gate.isCompleted && failSet.contains(key)) return false;
      values[key] = value;
      return true;
    });
    when(() => storage.remove(any())).thenAnswer((i) async {
      final key = i.positionalArguments[0] as String;
      if (slowDeletes.remove(key)) await gate.future;
      if (gate.isCompleted && failRemove.contains(key)) return false;
      values.remove(key);
      return true;
    });
    when(() => storage.getStringOrThrow(any())).thenAnswer(
      (i) async => values[i.positionalArguments[0] as String],
    );
  }

  final storage = _MockSecureStorage();
  final values = <String, String>{};
  final writes = <String>[];
  final gate = Completer<void>();
  final slowDeletes = <String>{};
  final failRemove = <String>{};
  final failSet = <String>{};
}

Future<void> _settle() => Future<void>.delayed(_bound * 6);

void main() {
  test('a stale cleared key reads as null, through any store over the '
      'service, and a later request carries no token', () async {
    final backing = _Backing()..failRemove.add(AppConstants.tokenKey);
    final store = SecureTokenStore(backing.storage, operationTimeout: _bound);

    final write = store.setAccessToken(_late); // a refresh write that stalls
    // The sign-out: its clear runs after the bound and succeeds.
    await store.clearAllTokens();
    backing.gate.complete(); // the write lands; every repair delete fails
    await write;
    await _settle();
    expect(
      backing.values[AppConstants.tokenKey],
      _late,
      reason: 'the device still holds the late token',
    );

    expect(await store.getAccessToken(), isNull);
    expect(
      await SecureTokenStore(backing.storage).getAccessToken(),
      isNull,
      reason: 'a second store over the service shares the stale state',
    );

    final interceptor = AuthInterceptor(
      secureStorageService: backing.storage,
      refreshToken: () async => const ResultFailure(UnknownFailure('unused')),
    );
    final options = RequestOptions(path: '/v1/tasks');
    await interceptor.onRequest(options, RequestInterceptorHandler());
    expect(options.headers['Authorization'], isNull);
  });

  test('a sign-out writes no token, even with a stale key whose newer state '
      'is a write', () async {
    final backing = _Backing()
      ..values[AppConstants.refreshTokenKey] = 'old'
      ..slowDeletes.add(AppConstants.refreshTokenKey)
      ..failSet.add(AppConstants.refreshTokenKey);
    final store = SecureTokenStore(backing.storage, operationTimeout: _bound);

    // A clear stalls; a new sign-in's write lands; the clear lands late, and
    // every repair re-write fails: the key is stale with a write newest.
    final clear = store.clearRefreshToken();
    await store.setRefreshToken('signed-in-again');
    backing.gate.complete();
    await clear;
    await _settle();
    expect(backing.values.containsKey(AppConstants.refreshTokenKey), isFalse);
    expect(await store.getRefreshToken(), 'signed-in-again');

    backing.writes.clear();
    await store.clearAllTokens();

    expect(backing.writes, isEmpty, reason: 'the sign-out wrote a token');
    expect(backing.values, isEmpty);
    expect(await store.getRefreshToken(), isNull);
  });
}
