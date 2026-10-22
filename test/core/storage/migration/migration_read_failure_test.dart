// A failed version read is not a fresh install.
//
// SecureStorageService.getString returns null both for a missing key and for
// a Keychain/Keystore read that throws. MigrationExecutor read that null as
// "first install": it stamped v1, re-ran every migration over data already
// migrated, and left the stamp at v1, so the next healthy launch ran the
// chain again. These tests drive the real SecureStorageService over a mocked
// plugin channel.

import 'package:flutter/services.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/storage/migration/migration_executor.dart';
import 'package:flutter_starter/core/storage/migration/storage_migration.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/storage/storage_version.dart';
import 'package:flutter_test/flutter_test.dart';

const _secureChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

/// A v1 -> v2 migration that only counts its runs.
class _CountingMigration extends StorageMigration {
  int runs = 0;

  @override
  int get fromVersion => 1;

  @override
  int get toVersion => 2;

  @override
  String get description => 'counting v1 -> v2';

  @override
  Future<void> migrate(IStorageService storage) async => runs++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final backing = <String, String>{};
  var readsFail = false;

  setUp(() {
    backing.clear();
    readsFail = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, (call) async {
          final args = call.arguments as Map<Object?, Object?>?;
          final key = args?['key'] as String? ?? '';
          switch (call.method) {
            case 'read':
              if (readsFail) {
                throw PlatformException(
                  code: 'KeychainError',
                  message: 'errSecInteractionNotAllowed',
                );
              }
              return backing[key];
            case 'write':
              backing[key] = args?['value'] as String? ?? '';
              return null;
            case 'delete':
              backing.remove(key);
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, null);
  });

  MigrationExecutor executorFor(_CountingMigration migration) =>
      MigrationExecutor(
        storage: SecureStorageService(),
        loggingService: LoggingService(enableLogging: false),
        migrations: [migration],
      );

  test('control: with reads working, a store at v2 is left alone', () async {
    backing[StorageVersion.versionKey] = '2';
    final migration = _CountingMigration();

    final result = await executorFor(migration).execute();

    expect(result, 2);
    expect(migration.runs, 0);
    expect(backing[StorageVersion.versionKey], '2');
  });

  test('a failing read on a v2 store runs no migration, keeps the stamp at '
      '2, and reports the failure', () async {
    backing[StorageVersion.versionKey] = '2';
    readsFail = true;
    final migration = _CountingMigration();

    await expectLater(
      executorFor(migration).execute(),
      throwsA(
        isA<MigrationExecutionException>().having(
          (e) => e.message,
          'message',
          contains('could not be read'),
        ),
      ),
    );

    expect(migration.runs, 0, reason: 'v2 data must not be migrated again');
    expect(
      backing[StorageVersion.versionKey],
      '2',
      reason: 'the stamp must not be overwritten with v1',
    );
  });

  test(
    'a genuinely empty store is still stamped initial and migrated',
    () async {
      final migration = _CountingMigration();

      final result = await executorFor(migration).execute();

      expect(migration.runs, 1);
      expect(result, 2);
      expect(backing[StorageVersion.versionKey], '2');
    },
  );

  test('getStringOrThrow throws where getString returns null', () async {
    backing['k'] = 'v';
    readsFail = true;
    final service = SecureStorageService();

    expect(await service.getString('k'), isNull);
    await expectLater(
      service.getStringOrThrow('k'),
      throwsA(isA<PlatformException>()),
    );
  });
}
