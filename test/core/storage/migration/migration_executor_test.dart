import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/storage/migration/migration_executor.dart';
import 'package:flutter_starter/core/storage/migration/migrations/migration_v1_to_v2.dart';
import 'package:flutter_starter/core/storage/migration/storage_migration.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/storage/storage_version.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MigrationExecutor', () {
    late StorageService storage;
    late LoggingService loggingService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = StorageService();
      await storage.init();
      loggingService = LoggingService(enableLogging: false);
    });

    tearDown(() async {
      await storage.clear();
    });

    test('execute returns current version when already at target', () async {
      await storage.setString(StorageVersion.versionKey, '2');

      final executor = MigrationExecutor(
        storage: storage,
        loggingService: loggingService,
        migrations: [MigrationV1ToV2()],
      );

      final result = await executor.execute();
      expect(result, equals(2));
    });

    test('execute runs migrations when version is behind', () async {
      await storage.setString(StorageVersion.versionKey, '1');
      // Set some old data to migrate
      await storage.setString('user_name', 'testuser');
      await storage.setString('theme', 'dark');

      final executor = MigrationExecutor(
        storage: storage,
        loggingService: loggingService,
        migrations: [MigrationV1ToV2()],
      );

      final result = await executor.execute();
      expect(result, equals(2));

      // Verify migration happened
      final username = await storage.getString('username');
      expect(username, equals('testuser'));
      expect(await storage.containsKey('user_name'), isFalse);

      final themeMode = await storage.getString('theme_mode');
      expect(themeMode, equals('dark'));
      expect(await storage.containsKey('theme'), isFalse);
    });

    test('execute sets initial version for first install', () async {
      // No version set (first install)
      final executor = MigrationExecutor(
        storage: storage,
        loggingService: loggingService,
        migrations: [MigrationV1ToV2()],
      );

      final result = await executor.execute();
      expect(result, equals(StorageVersion.current));

      final version = await storage.getString(StorageVersion.versionKey);
      expect(version, equals(StorageVersion.current.toString()));
    });

    test('execute handles corrupted version gracefully', () async {
      await storage.setString(StorageVersion.versionKey, 'invalid');

      final executor = MigrationExecutor(
        storage: storage,
        loggingService: loggingService,
        migrations: [MigrationV1ToV2()],
      );

      final result = await executor.execute();
      expect(result, equals(StorageVersion.current));

      final version = await storage.getString(StorageVersion.versionKey);
      expect(version, equals(StorageVersion.current.toString()));
    });

    test('execute runs migrations in correct order', () async {
      await storage.setString(StorageVersion.versionKey, '1');

      // Create a test migration that tracks execution order
      final executionOrder = <int>[];

      final migration1 = _TestMigration(
        fromVersion: 1,
        toVersion: 2,
        onExecute: () => executionOrder.add(1),
      );
      final migration2 = _TestMigration(
        fromVersion: 2,
        toVersion: 3,
        onExecute: () => executionOrder.add(2),
      );

      final executor = MigrationExecutor(
        storage: storage,
        loggingService: loggingService,
        migrations: [migration2, migration1], // Intentionally out of order
      );

      // Since StorageVersion.current is 2, only migration1 should run
      await executor.execute();

      // Verify migrations executed in order (only migration1 should run)
      expect(executionOrder, equals([1]));
    });

    test(
      'execute throws MigrationExecutionException on migration failure',
      () async {
        await storage.setString(StorageVersion.versionKey, '1');

        final failingMigration = _FailingMigration();

        final executor = MigrationExecutor(
          storage: storage,
          loggingService: loggingService,
          migrations: [failingMigration],
        );

        expect(executor.execute, throwsA(isA<MigrationExecutionException>()));
      },
    );

    // A missing migration path used to log a warning and return the stale
    // version, which every caller discards - so the app started and read
    // new-shaped keys off old-shaped data.
    group('missing migration path (#60)', () {
      test('throws when no migration reaches the target version', () async {
        await storage.setString(StorageVersion.versionKey, '1');

        final executor = MigrationExecutor(
          storage: storage,
          loggingService: loggingService,
          migrations: const [],
        );

        await expectLater(
          executor.execute(),
          throwsA(
            isA<MigrationPathException>()
                .having((e) => e.currentVersion, 'currentVersion', 1)
                .having(
                  (e) => e.targetVersion,
                  'targetVersion',
                  StorageVersion.current,
                )
                .having((e) => e.missingFromVersion, 'missingFromVersion', 1)
                .having(
                  (e) => '$e',
                  'toString',
                  startsWith('MigrationPathException:'),
                ),
          ),
        );

        // Nothing ran, so the stamp is untouched.
        expect(await storage.getString(StorageVersion.versionKey), '1');
      });

      test('throws on a mid-chain gap (v1->v2, v3->v4, target 4)', () async {
        await storage.setString(StorageVersion.versionKey, '1');

        final executed = <int>[];
        final executor = MigrationExecutor(
          storage: storage,
          loggingService: loggingService,
          targetVersion: 4,
          migrations: [
            _TestMigration(
              fromVersion: 1,
              toVersion: 2,
              onExecute: () => executed.add(1),
            ),
            _TestMigration(
              fromVersion: 3,
              toVersion: 4,
              onExecute: () => executed.add(3),
            ),
          ],
        );

        await expectLater(
          executor.execute(),
          throwsA(
            isA<MigrationPathException>().having(
              (e) => e.missingFromVersion,
              'missingFromVersion',
              2,
            ),
          ),
        );

        // The chain is planned before anything runs, so v1->v2 did not fire
        // and storage was not left half-migrated.
        expect(executed, isEmpty);
        expect(await storage.getString(StorageVersion.versionKey), '1');
      });

      test('throws when a migration overshoots the target version', () async {
        await storage.setString(StorageVersion.versionKey, '1');

        final executor = MigrationExecutor(
          storage: storage,
          loggingService: loggingService,
          // targetVersion left at StorageVersion.current (2).
          migrations: [
            _TestMigration(fromVersion: 1, toVersion: 4, onExecute: () {}),
          ],
        );

        await expectLater(
          executor.execute(),
          throwsA(isA<MigrationPathException>()),
        );
      });
    });

    group('downgrade detection (#60)', () {
      test('throws distinctly when stored version is newer', () async {
        await storage.setString(
          StorageVersion.versionKey,
          '${StorageVersion.current + 1}',
        );

        final executor = MigrationExecutor(
          storage: storage,
          loggingService: loggingService,
          migrations: [MigrationV1ToV2()],
        );

        await expectLater(
          executor.execute(),
          throwsA(
            isA<StorageDowngradeException>()
                .having(
                  (e) => e.storedVersion,
                  'storedVersion',
                  StorageVersion.current + 1,
                )
                .having(
                  (e) => e.supportedVersion,
                  'supportedVersion',
                  StorageVersion.current,
                )
                // Asserted on the real thrown object, not just a hand-built
                // one: #142 was found through a widget test failing with
                // `Found 0 widgets`, which reads as "wrong screen" rather
                // than "wrong class name". Here it fails at the throw site.
                .having(
                  (e) => '$e',
                  'toString',
                  startsWith('StorageDowngradeException:'),
                ),
          ),
        );
      });

      test('an exact version match is still a plain success', () async {
        await storage.setString(
          StorageVersion.versionKey,
          '${StorageVersion.current}',
        );

        final executor = MigrationExecutor(
          storage: storage,
          loggingService: loggingService,
          migrations: [MigrationV1ToV2()],
        );

        expect(await executor.execute(), StorageVersion.current);
      });
    });

    group('version stamp write failure (#60)', () {
      test('surfaces a rejected version write instead of returning', () async {
        await storage.setString(StorageVersion.versionKey, '1');
        final failingStamp = _VersionWriteFailingStorage(storage);

        final executor = MigrationExecutor(
          storage: failingStamp,
          loggingService: loggingService,
          migrations: [MigrationV1ToV2()],
        );

        await expectLater(
          executor.execute(),
          throwsA(isA<MigrationExecutionException>()),
        );
      });
    });
  });

  // These assert the exact string, not `contains`, because the string itself
  // is the product: `main()` renders `'$error'` verbatim into
  // `StartupFailureApp`, so this is what a user quotes in a bug report.
  group('exception toString (#142)', () {
    test('the base class names itself and keeps its original-exception '
        'line', () {
      expect(
        MigrationExecutionException('boom').toString(),
        'MigrationExecutionException: boom',
      );
      expect(
        MigrationExecutionException(
          'boom',
          originalException: StateError('inner'),
        ).toString(),
        'MigrationExecutionException: boom\n'
        'Original exception: Bad state: inner',
      );
    });

    test('a downgrade refusal names itself, not its parent', () {
      final exception = StorageDowngradeException(
        'boom',
        storedVersion: 3,
        supportedVersion: 2,
      );

      expect(exception.toString(), startsWith('StorageDowngradeException:'));
      expect(exception.toString(), 'StorageDowngradeException: boom');
    });

    test('a missing migration path names itself, not its parent', () {
      final exception = MigrationPathException(
        'boom',
        currentVersion: 1,
        targetVersion: 2,
        missingFromVersion: 1,
      );

      expect(exception.toString(), startsWith('MigrationPathException:'));
      expect(exception.toString(), 'MigrationPathException: boom');
    });
  });
}

/// Storage that accepts every write except the version stamp
///
/// Models `SecureStorageService` on a device with no usable Keychain: it
/// swallows its own errors and returns false rather than throwing.
class _VersionWriteFailingStorage implements IStorageService {
  _VersionWriteFailingStorage(this._inner);

  final IStorageService _inner;

  @override
  Future<bool> setString(String key, String value) async {
    if (key == StorageVersion.versionKey) return false;
    return _inner.setString(key, value);
  }

  @override
  Future<String?> getString(String key) => _inner.getString(key);

  @override
  Future<int?> getInt(String key) => _inner.getInt(key);

  @override
  Future<bool> setInt(String key, int value) => _inner.setInt(key, value);

  @override
  Future<bool?> getBool(String key) => _inner.getBool(key);

  @override
  Future<bool> setBool(String key, {required bool value}) =>
      _inner.setBool(key, value: value);

  @override
  Future<double?> getDouble(String key) => _inner.getDouble(key);

  @override
  Future<bool> setDouble(String key, double value) =>
      _inner.setDouble(key, value);

  @override
  Future<List<String>?> getStringList(String key) => _inner.getStringList(key);

  @override
  Future<bool> setStringList(String key, List<String> value) =>
      _inner.setStringList(key, value);

  @override
  Future<bool> remove(String key) => _inner.remove(key);

  @override
  Future<bool> clear() => _inner.clear();

  @override
  Future<bool> containsKey(String key) => _inner.containsKey(key);
}

/// Test migration that tracks execution
class _TestMigration extends StorageMigration {
  _TestMigration({
    required this.fromVersion,
    required this.toVersion,
    required this.onExecute,
  });

  @override
  final int fromVersion;

  @override
  final int toVersion;

  @override
  String get description => 'Test migration from $fromVersion to $toVersion';

  final VoidCallback onExecute;

  @override
  Future<void> migrate(IStorageService storage) async {
    onExecute();
  }
}

/// Migration that always fails
class _FailingMigration extends StorageMigration {
  @override
  int get fromVersion => 1;

  @override
  int get toVersion => 2;

  @override
  String get description => 'Failing migration';

  @override
  Future<void> migrate(IStorageService storage) async {
    throw Exception('Migration failed');
  }
}
