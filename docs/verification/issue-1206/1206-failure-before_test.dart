import 'dart:async';

import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/contracts/storage_contracts.dart';
import '1206-before-adapter.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '1206-before-memory.dart';

class _SecureService extends Mock implements SecureStorageService {}

class _Vault {
  _Vault() {
    when(() => service.getStringOrThrow(any())).thenAnswer((call) async {
      final captured = values[call.positionalArguments[0] as String];
      if (holdRead) {
        holdRead = false;
        readEntered.complete();
        await releaseRead.future;
      }
      return captured;
    });
    when(() => service.setString(any(), any())).thenAnswer((call) async {
      final key = call.positionalArguments[0] as String;
      final value = call.positionalArguments[1] as String;
      writes.add(value);
      final number = writes.length;
      if (value == heldWriteValue && !writeEntered.isCompleted) {
        writeEntered.complete();
        await releaseWrite.future;
      }
      final error = writeError?.call(number);
      final failed = failWrite?.call(number) ?? false;
      if (effectBeforeFailure && (failed || error != null)) values[key] = value;
      if (error != null) Error.throwWithStackTrace(error, StackTrace.current);
      if (failed) return false;
      values[key] = value;
      return true;
    });
    when(() => service.remove(any())).thenAnswer((call) async {
      values.remove(call.positionalArguments[0] as String);
      return true;
    });
  }

  final service = _SecureService();
  final values = <String, String>{
    AppConstants.tokenKey: 'A1',
    AppConstants.refreshTokenKey: 'R1',
  };
  final writes = <String>[];
  bool holdRead = false;
  String? heldWriteValue;
  bool Function(int)? failWrite;
  Object? Function(int)? writeError;
  bool effectBeforeFailure = false;
  final readEntered = Completer<void>();
  final releaseRead = Completer<void>();
  final writeEntered = Completer<void>();
  final releaseWrite = Completer<void>();
}

Future<T> _within<T>(Future<T> future) =>
    future.timeout(const Duration(seconds: 5));

void main() {
  test(
    'a shared revision permits one conditional write and rejects reuse',
    () async {
      final vault = _Vault();
      final first = SecureTokenStore(vault.service);
      final second = SecureTokenStore(vault.service);
      final snapshot = (await first.getAccessTokenSnapshot())!;
      expect(snapshot.token, 'A1');
      expect(identical(snapshot.revision, second.credentialRevision), isTrue);
      final pending = second.setAccessTokenIfCurrent(snapshot, 'A2');
      expect(identical(snapshot.revision, first.credentialRevision), isFalse);
      expect(await pending, AccessTokenWriteResult.applied);
      expect(
        await first.setAccessTokenIfCurrent(snapshot, 'stale'),
        AccessTokenWriteResult.conflict,
      );
      expect((await first.getAccessTokenSnapshot())!.token, 'A2');
      expect(vault.writes, ['A2']);
    },
  );

  test('snapshots from another service cannot authorize writes', () async {
    final source = SecureTokenStore(_Vault().service);
    final targetVault = _Vault();
    final target = SecureTokenStore(targetVault.service);
    final snapshot = (await source.getAccessTokenSnapshot())!;
    expect(
      await target.setAccessTokenIfCurrent(snapshot, 'foreign'),
      AccessTokenWriteResult.conflict,
    );
    expect(targetVault.writes, isEmpty);
  });

  test('ABA and refresh-only mutations invalidate old snapshots', () async {
    final vault = _Vault();
    final store = SecureTokenStore(vault.service);
    final initial = (await store.getAccessTokenSnapshot())!;
    await store.setAccessToken('B');
    await store.setAccessToken('A1');
    expect(
      await store.setAccessTokenIfCurrent(initial, 'old'),
      AccessTokenWriteResult.conflict,
    );
    final afterAba = (await store.getAccessTokenSnapshot())!;
    await store.setRefreshToken('R2');
    expect(
      await store.setAccessTokenIfCurrent(afterAba, 'old'),
      AccessTokenWriteResult.conflict,
    );
    expect(await store.getAccessToken(), 'A1');
  });

  test(
    'clear invalidates a snapshot and a certified null is a valid state',
    () async {
      final vault = _Vault();
      final store = SecureTokenStore(vault.service);
      final before = (await store.getAccessTokenSnapshot())!;
      await store.clearAllTokens();
      expect(
        await store.setAccessTokenIfCurrent(before, 'resurrected'),
        AccessTokenWriteResult.conflict,
      );
      final cleared = (await store.getAccessTokenSnapshot())!;
      expect(cleared.token, isNull);
      expect(vault.values, isEmpty);
      expect(
        await store.setAccessTokenIfCurrent(cleared, 'new-session'),
        AccessTokenWriteResult.applied,
      );
    },
  );

  test('a write issued during a held read prevents certification', () async {
    final vault = _Vault()..holdRead = true;
    final store = SecureTokenStore(vault.service);
    final pending = store.getAccessTokenSnapshot();
    await _within(vault.readEntered.future);
    final write = store.setAccessToken('A2');
    vault.releaseRead.complete();
    expect(await _within(pending), isNull);
    await write;
    expect((await store.getAccessTokenSnapshot())!.token, 'A2');
  });

  test(
    'a timed out snapshot read never publishes its later stale value',
    () async {
      final vault = _Vault()..holdRead = true;
      final store = SecureTokenStore(
        vault.service,
        operationTimeout: const Duration(milliseconds: 5),
      );
      final pending = store.getAccessTokenSnapshot();
      await _within(vault.readEntered.future);
      await _within(store.setAccessToken('A3'));
      expect(await _within(pending), isNull);
      vault.releaseRead.complete();
      expect((await store.getAccessTokenSnapshot())!.token, 'A3');
    },
  );

  test('a pending platform write makes a bypassed snapshot unusable', () async {
    final vault = _Vault()..heldWriteValue = 'A2';
    final store = SecureTokenStore(
      vault.service,
      operationTimeout: const Duration(milliseconds: 5),
    );
    final write = store.setAccessToken('A2');
    await _within(vault.writeEntered.future);
    expect(await _within(store.getAccessTokenSnapshot()), isNull);
    vault.releaseWrite.complete();
    await write;
    expect((await store.getAccessTokenSnapshot())!.token, 'A2');
  });

  test(
    'conditional order is reserved before waiting behind an old read',
    () async {
      final vault = _Vault();
      final store = SecureTokenStore(
        vault.service,
        operationTimeout: const Duration(milliseconds: 5),
      );
      final snapshot = (await store.getAccessTokenSnapshot())!;
      vault.holdRead = true;
      final heldRead = store.getAccessToken();
      await _within(vault.readEntered.future);
      final conditional = store.setAccessTokenIfCurrent(snapshot, 'candidate');
      expect(identical(snapshot.revision, store.credentialRevision), isFalse);
      await _within(store.setAccessToken('newer'));
      expect(await _within(conditional), AccessTokenWriteResult.conflict);
      vault.releaseRead.complete();
      await heldRead;
      expect(vault.writes, ['newer']);
      expect((await store.getAccessTokenSnapshot())!.token, 'newer');
    },
  );

  for (final (repairFails, clear) in [
    (false, false),
    (true, false),
    (false, true),
  ]) {
    test(
      'late conditional write respects newer state '
      '(repair fails: $repairFails, clear: $clear)',
      () async {
        final vault = _Vault()..heldWriteValue = 'candidate';
        if (repairFails) vault.failWrite = (call) => call >= 3;
        final store = SecureTokenStore(
          vault.service,
          operationTimeout: const Duration(milliseconds: 5),
        );
        final snapshot = (await store.getAccessTokenSnapshot())!;
        final conditional = store.setAccessTokenIfCurrent(
          snapshot,
          'candidate',
        );
        await _within(vault.writeEntered.future);
        if (clear) {
          await _within(store.clearAllTokens());
        } else {
          await _within(store.setAccessToken('newer'));
        }
        expect(await _within(store.getAccessTokenSnapshot()), isNull);
        vault.releaseWrite.complete();
        expect(await _within(conditional), AccessTokenWriteResult.conflict);
        await pumpEventQueue();
        final latest = await store.getAccessTokenSnapshot();
        expect(latest, isNotNull);
        expect(latest!.token, clear ? isNull : 'newer');
        expect(
          vault.values[AppConstants.tokenKey],
          clear ? isNull : (repairFails ? 'candidate' : 'newer'),
        );
      },
    );
  }

  test(
    'a queued repair prevents certification before it reaches the platform',
    () async {
      final vault = _Vault()..heldWriteValue = 'candidate';
      final slow = SecureTokenStore(vault.service);
      final bypass = SecureTokenStore(
        vault.service,
        operationTimeout: Duration.zero,
      );
      final snapshot = (await slow.getAccessTokenSnapshot())!;
      final conditional = slow.setAccessTokenIfCurrent(snapshot, 'candidate');
      await _within(vault.writeEntered.future);
      await _within(bypass.setAccessToken('newer'));
      vault.holdRead = true;
      final heldRead = bypass.getAccessToken();
      await _within(vault.readEntered.future);
      vault.releaseWrite.complete();
      expect(await _within(conditional), AccessTokenWriteResult.conflict);
      expect(vault.values[AppConstants.tokenKey], 'candidate');
      expect(vault.writes, [
        'candidate',
        'newer',
      ], reason: 'repair still queued');
      expect(await _within(bypass.getAccessTokenSnapshot()), isNull);
      vault.releaseRead.complete();
      await heldRead;
      await pumpEventQueue();
      expect((await slow.getAccessTokenSnapshot())!.token, 'newer');
    },
  );

  test(
    'an old conditional write error cannot mask a superseding mutation',
    () async {
      final vault = _Vault()
        ..heldWriteValue = 'candidate'
        ..writeError = (call) =>
            call == 1 ? StateError('platform failed') : null;
      final store = SecureTokenStore(
        vault.service,
        operationTimeout: const Duration(milliseconds: 5),
      );
      final snapshot = (await store.getAccessTokenSnapshot())!;
      final conditional = store.setAccessTokenIfCurrent(snapshot, 'candidate');
      await _within(vault.writeEntered.future);
      await _within(store.setAccessToken('newer'));
      vault.releaseWrite.complete();
      expect(await _within(conditional), AccessTokenWriteResult.conflict);
      expect((await store.getAccessTokenSnapshot())!.token, 'newer');
    },
  );

  for (final throws in [false, true]) {
    for (final clear in [false, true]) {
      test('late failure after its effect preserves newer state '
          '(throw: $throws, clear: $clear)', () async {
        final vault = _Vault()
          ..heldWriteValue = 'candidate'
          ..effectBeforeFailure = true;
        if (throws) {
          vault.writeError = (call) =>
              call == 1 ? StateError('lost acknowledgement') : null;
        } else {
          vault.failWrite = (call) => call == 1;
        }
        final store = SecureTokenStore(
          vault.service,
          operationTimeout: const Duration(milliseconds: 5),
        );
        final snapshot = (await store.getAccessTokenSnapshot())!;
        final conditional = store.setAccessTokenIfCurrent(
          snapshot,
          'candidate',
        );
        await _within(vault.writeEntered.future);
        if (clear) {
          await _within(store.clearAllTokens());
        } else {
          await _within(store.setAccessToken('newer'));
        }
        vault.releaseWrite.complete();
        expect(await _within(conditional), AccessTokenWriteResult.conflict);
        await pumpEventQueue();
        final latest = await store.getAccessTokenSnapshot();
        expect(latest, isNotNull);
        expect(latest!.token, clear ? isNull : 'newer');
        expect(vault.values[AppConstants.tokenKey], clear ? isNull : 'newer');
      });
    }
  }

  test(
    'platform failure differs from supersession and consumes the revision',
    () async {
      final vault = _Vault()..failWrite = (_) => true;
      final store = SecureTokenStore(vault.service);
      final snapshot = (await store.getAccessTokenSnapshot())!;
      expect(
        await store.setAccessTokenIfCurrent(snapshot, 'failed'),
        AccessTokenWriteResult.failed,
      );
      expect(identical(snapshot.revision, store.credentialRevision), isFalse);
      expect(await store.getAccessToken(), 'A1');
      expect(
        await store.setAccessTokenIfCurrent(snapshot, 'retry-old'),
        AccessTokenWriteResult.conflict,
      );
    },
  );

  test(
    'the in-memory implementation tracks direct seeding and ABA too',
    () async {
      final store = InMemoryTokenStore()..accessToken = 'A1';
      final snapshot = (await store.getAccessTokenSnapshot())!;
      store
        ..accessToken = 'B'
        ..accessToken = 'A1';
      expect(
        await store.setAccessTokenIfCurrent(snapshot, 'old'),
        AccessTokenWriteResult.conflict,
      );
      final current = (await store.getAccessTokenSnapshot())!;
      expect(
        await store.setAccessTokenIfCurrent(current, 'new'),
        AccessTokenWriteResult.applied,
      );
      expect(store.accessToken, 'new');
    },
  );
}
