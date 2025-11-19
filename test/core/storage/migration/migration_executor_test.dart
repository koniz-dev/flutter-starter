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
      expect(result, greaterThanOrEqualTo(StorageVersion.initial));

      final version = await storage.getString(StorageVersion.versionKey);
      expect(version, isNotNull);
    });

    test('execute handles corrupted version gracefully', () async {
      await storage.setString(StorageVersion.versionKey, 'invalid');

      final executor = MigrationExecutor(
        storage: storage,
        loggingService: loggingService,
        migrations: [MigrationV1ToV2()],
      );

      final result = await executor.execute();
      expect(result, greaterThanOrEqualTo(StorageVersion.initial));

      final version = await storage.getString(StorageVersion.versionKey);
      expect(int.tryParse(version ?? ''), isNotNull);
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

    test('execute throws MigrationExecutionException on migration failure',
        () async {
      await storage.setString(StorageVersion.versionKey, '1');

      final failingMigration = _FailingMigration();

      final executor = MigrationExecutor(
        storage: storage,
        loggingService: loggingService,
        migrations: [failingMigration],
      );

      expect(
        executor.execute,
        throwsA(isA<MigrationExecutionException>()),
      );
    });
  });
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
