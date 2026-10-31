// SecureTokenStore runs its operations in order, so one platform call that
// never completed held every later one - each request's token read, a
// logout's clear - until the app restarted. Each operation is now bounded.

import 'dart:async';

import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/storage/adapters/secure_token_store.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements SecureStorageService {}

void main() {
  test('a write that never completes fails after the bound, and the reads '
      'and the clear behind it still run', () async {
    final values = <String, String>{AppConstants.tokenKey: 'old'};
    final storage = _MockSecureStorage();
    when(
      () => storage.setString(any(), any()),
    ).thenAnswer((_) => Completer<bool>().future); // never completes
    when(() => storage.getStringOrThrow(any())).thenAnswer(
      (i) async => values[i.positionalArguments[0] as String],
    );
    when(() => storage.remove(any())).thenAnswer((i) async {
      values.remove(i.positionalArguments[0] as String);
      return true;
    });
    final store = SecureTokenStore(
      storage,
      operationTimeout: const Duration(milliseconds: 100),
    );

    final write = store.setAccessToken('new');
    final read = store.getAccessToken();
    final clear = store.clearAllTokens();

    await expectLater(write, throwsA(isA<CacheException>()));
    expect(await read, 'old', reason: 'the read ran once the write gave up');
    await clear;
    expect(values, isEmpty, reason: 'the logout clear ran');
  });

  test('operations that complete in time keep their order', () async {
    final values = <String, String>{};
    final storage = _MockSecureStorage();
    when(() => storage.setString(any(), any())).thenAnswer((i) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      values[i.positionalArguments[0] as String] =
          i.positionalArguments[1] as String;
      return true;
    });
    when(() => storage.remove(any())).thenAnswer((i) async {
      values.remove(i.positionalArguments[0] as String);
      return true;
    });
    final store = SecureTokenStore(storage);

    await (store.setAccessToken('x'), store.clearAllTokens()).wait;

    expect(values, isEmpty);
  });
}
