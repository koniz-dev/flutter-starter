import 'package:flutter_starter/core/storage/migration/migrations/migration_v1_to_v2.dart';
import 'package:flutter_starter/core/storage/migration/storage_migration.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/storage/storage_version.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('StorageMigration', () {
    late StorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = StorageService();
      await storage.init();
    });

    tearDown(() async {
      await storage.clear();
    });

    test('canMigrate returns true when version matches', () async {
      // Set version to 1
      await storage.setString(StorageVersion.versionKey, '1');

      final migration = MigrationV1ToV2();
      final canMigrate = await migration.canMigrate(storage);

      expect(canMigrate, isTrue);
    });

    test('canMigrate returns false when version does not match', () async {
      // Set version to 2 (already migrated)
      await storage.setString(StorageVersion.versionKey, '2');

      final migration = MigrationV1ToV2();
      final canMigrate = await migration.canMigrate(storage);

      expect(canMigrate, isFalse);
    });

    test(
      'canMigrate returns true for initial version when no version set',
      () async {
      // No version set (first install)
      final migration = MigrationV1ToV2();
      final canMigrate = await migration.canMigrate(storage);

      // Should return false because initial version is 1, but migration
      // expects fromVersion 1. Actually, if no version is set, it defaults
      // to initial (1), so this should work
      expect(canMigrate, isTrue);
    });

    test('execute updates version after successful migration', () async {
      await storage.setString(StorageVersion.versionKey, '1');

      final migration = MigrationV1ToV2();
      await migration.execute(storage);

      final version = await storage.getString(StorageVersion.versionKey);
      expect(version, equals('2'));
    });

    test('execute throws MigrationException when version mismatch', () async {
      await storage.setString(StorageVersion.versionKey, '2');

      final migration = MigrationV1ToV2();

      expect(
        () => migration.execute(storage),
        throwsA(isA<MigrationException>()),
      );
    });
  });
}
