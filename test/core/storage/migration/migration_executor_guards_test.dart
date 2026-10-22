// MigrationExecutor's guards, each pinned by a test that fails when the guard
// is removed. The audit found all three
// survived their mutants: the final version-stamp check, the sort by
// fromVersion, and the reset of a stored version below the initial one.

import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/storage/migration/migration_executor.dart';
import 'package:flutter_starter/core/storage/migration/storage_migration.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/storage/storage_version.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records the order migrations run in; stamps its own version normally.
class _Recording extends StorageMigration {
  _Recording(this.fromVersion, this.log);

  @override
  final int fromVersion;

  final List<int> log;

  @override
  int get toVersion => fromVersion + 1;

  @override
  String get description => 'v$fromVersion -> v$toVersion';

  @override
  Future<void> migrate(IStorageService storage) async => log.add(fromVersion);
}

/// Overrides execute() and forgets to stamp the version.
class _ForgetsToStamp extends StorageMigration {
  @override
  int get fromVersion => 1;

  @override
  int get toVersion => 2;

  @override
  String get description => 'forgets to stamp';

  @override
  Future<void> migrate(IStorageService storage) async {}

  @override
  Future<void> execute(IStorageService storage) => migrate(storage);
}

void main() {
  late StorageService storage;
  final logging = LoggingService(enableLogging: false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
  });

  test(
    'criterion 1: a migration that skips the version stamp fails the run',
    () async {
      await storage.setString(StorageVersion.versionKey, '1');

      final executor = MigrationExecutor(
        storage: storage,
        loggingService: logging,
        migrations: [_ForgetsToStamp()],
      );

      await expectLater(
        executor.execute(),
        throwsA(isA<MigrationExecutionException>()),
      );
      expect(await storage.getString(StorageVersion.versionKey), '1');
    },
  );

  test('criterion 2: migrations registered out of order run in fromVersion '
      'order', () async {
    await storage.setString(StorageVersion.versionKey, '1');
    final log = <int>[];

    final executor = MigrationExecutor(
      storage: storage,
      loggingService: logging,
      migrations: [_Recording(3, log), _Recording(1, log), _Recording(2, log)],
      targetVersion: 4,
    );

    expect(await executor.execute(), 4);
    expect(log, [1, 2, 3]);
  });

  for (final stored in const ['0', '-1']) {
    test('criterion 3: a stored version of $stored is reset to the initial '
        'version', () async {
      await storage.setString(StorageVersion.versionKey, stored);

      final executor = MigrationExecutor(
        storage: storage,
        loggingService: logging,
        migrations: const [],
        targetVersion: StorageVersion.initial,
      );

      expect(await executor.execute(), StorageVersion.initial);
      expect(
        await storage.getString(StorageVersion.versionKey),
        StorageVersion.initial.toString(),
      );
    });
  }
}
