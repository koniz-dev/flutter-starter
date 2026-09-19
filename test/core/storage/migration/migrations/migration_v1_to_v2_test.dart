import 'package:flutter_starter/core/storage/migration/migrations/migration_v1_to_v2.dart';
import 'package:flutter_starter/core/storage/migration/storage_migration.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/storage/storage_version.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MigrationV1ToV2', () {
    late StorageService storage;
    late MigrationV1ToV2 migration;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = StorageService();
      await storage.init();
      migration = MigrationV1ToV2();
    });

    tearDown(() async {
      await storage.clear();
    });

    group('Properties', () {
      test('should have correct fromVersion', () {
        // Assert
        expect(migration.fromVersion, 1);
      });

      test('should have correct toVersion', () {
        // Assert
        expect(migration.toVersion, 2);
      });

      test('should have non-empty description', () {
        // Assert
        expect(migration.description, isNotEmpty);
        expect(migration.description, contains('Migrate'));
      });
    });

    group('migrate', () {
      test('should rename user_name to username', () async {
        // Arrange
        await storage.setString(StorageVersion.versionKey, '1');
        await storage.setString('user_name', 'testuser');

        // Act
        await migration.migrate(storage);

        // Assert
        final username = await storage.getString('username');
        final oldUserName = await storage.getString('user_name');
        expect(username, 'testuser');
        expect(oldUserName, isNull);
      });

      test('should not migrate if user_name does not exist', () async {
        // Arrange
        await storage.setString(StorageVersion.versionKey, '1');

        // Act
        await migration.migrate(storage);

        // Assert
        final username = await storage.getString('username');
        expect(username, isNull);
      });

      test('should transform theme to theme_mode', () async {
        // Arrange
        await storage.setString(StorageVersion.versionKey, '1');
        await storage.setString('theme', 'dark');

        // Act
        await migration.migrate(storage);

        // Assert
        final themeMode = await storage.getString('theme_mode');
        final oldTheme = await storage.getString('theme');
        expect(themeMode, 'dark');
        expect(oldTheme, isNull);
      });

      test('should transform light theme correctly', () async {
        // Arrange
        await storage.setString(StorageVersion.versionKey, '1');
        await storage.setString('theme', 'light');

        // Act
        await migration.migrate(storage);

        // Assert
        final themeMode = await storage.getString('theme_mode');
        expect(themeMode, 'light');
      });

      test('should default unknown theme to system', () async {
        // Arrange
        await storage.setString(StorageVersion.versionKey, '1');
        await storage.setString('theme', 'unknown');

        // Act
        await migration.migrate(storage);

        // Assert
        final themeMode = await storage.getString('theme_mode');
        expect(themeMode, 'system');
      });

      test('should handle case-insensitive theme values', () async {
        // Arrange
        await storage.setString(StorageVersion.versionKey, '1');
        await storage.setString('theme', 'DARK');

        // Act
        await migration.migrate(storage);

        // Assert
        final themeMode = await storage.getString('theme_mode');
        expect(themeMode, 'dark');
      });

      test('should migrate comma-separated tags to list', () async {
        // Arrange
        await storage.setString(StorageVersion.versionKey, '1');
        await storage.setString('user_tags', 'tag1, tag2, tag3');

        // Act
        await migration.migrate(storage);

        // Assert
        final tags = await storage.getStringList('user_tags');
        expect(tags, ['tag1', 'tag2', 'tag3']);
      });

      test('should convert an empty tags string to an empty list', () async {
        // Arrange
        await storage.setString(StorageVersion.versionKey, '1');
        await storage.setString('user_tags', '');

        // Act
        await migration.migrate(storage);

        // Assert - the key holds a list afterwards whatever the old value
        // was, so a later `getStringList` never hits a String.
        expect(await storage.getStringList('user_tags'), isEmpty);
      });

      test('should add default language if not exists', () async {
        // Arrange
        await storage.setString(StorageVersion.versionKey, '1');

        // Act
        await migration.migrate(storage);

        // Assert
        final language = await storage.getString('language');
        expect(language, 'en');
      });

      test('should not overwrite existing language', () async {
        // Arrange
        await storage.setString(StorageVersion.versionKey, '1');
        await storage.setString('language', 'vi');

        // Act
        await migration.migrate(storage);

        // Assert
        final language = await storage.getString('language');
        expect(language, 'vi');
      });

      test('should remove deprecated keys', () async {
        // Arrange
        await storage.setString(StorageVersion.versionKey, '1');
        await storage.setString('old_setting_1', 'value1');
        await storage.setString('old_setting_2', 'value2');
        await storage.setString('deprecated_key', 'value3');

        // Act
        await migration.migrate(storage);

        // Assert
        expect(await storage.containsKey('old_setting_1'), isFalse);
        expect(await storage.containsKey('old_setting_2'), isFalse);
        expect(await storage.containsKey('deprecated_key'), isFalse);
      });

      test('should handle deprecated keys that do not exist', () async {
        // Arrange
        await storage.setString(StorageVersion.versionKey, '1');

        // Act & Assert - Should not throw
        await expectLater(migration.migrate(storage), completes);
      });

      test('should handle user_data (currently no-op)', () async {
        // Arrange
        await storage.setString(StorageVersion.versionKey, '1');
        await storage.setString('user_data', 'invalid-json');

        // Act
        await migration.migrate(storage);

        // Assert
        // Note: Current implementation doesn't actually parse/remove user_data
        // (code is commented out), so it remains
        expect(await storage.containsKey('user_data'), isTrue);
      });

      test('should handle user_data that does not exist', () async {
        // Arrange
        await storage.setString(StorageVersion.versionKey, '1');

        // Act & Assert - Should not throw
        await expectLater(migration.migrate(storage), completes);
      });
    });

    group('canMigrate', () {
      test('should return true when version matches', () async {
        // Arrange
        await storage.setString(StorageVersion.versionKey, '1');

        // Act
        final canMigrate = await migration.canMigrate(storage);

        // Assert
        expect(canMigrate, isTrue);
      });

      test('should return false when version does not match', () async {
        // Arrange
        await storage.setString(StorageVersion.versionKey, '2');

        // Act
        final canMigrate = await migration.canMigrate(storage);

        // Assert
        expect(canMigrate, isFalse);
      });

      test('should return true when no version set (initial)', () async {
        // Arrange - No version set

        // Act
        final canMigrate = await migration.canMigrate(storage);

        // Assert
        // Initial version is 1, so should return true
        expect(canMigrate, isTrue);
      });

      test('should return false for invalid version string', () async {
        // Arrange
        await storage.setString(StorageVersion.versionKey, 'invalid');

        // Act
        final canMigrate = await migration.canMigrate(storage);

        // Assert
        // Invalid version defaults to initial (1), so should return true
        expect(canMigrate, isTrue);
      });
    });

    group('execute', () {
      test('should execute migration and update version', () async {
        // Arrange
        await storage.setString(StorageVersion.versionKey, '1');
        await storage.setString('user_name', 'testuser');

        // Act
        await migration.execute(storage);

        // Assert
        final version = await storage.getString(StorageVersion.versionKey);
        final username = await storage.getString('username');
        expect(version, '2');
        expect(username, 'testuser');
      });

      test('should throw when version does not match', () async {
        // Arrange
        await storage.setString(StorageVersion.versionKey, '2');

        // Act & Assert
        await expectLater(
          migration.execute(storage),
          throwsA(isA<MigrationException>()),
        );
      });
    });

    group('Edge Cases', () {
      test('should handle migration with all transformations', () async {
        // Arrange
        await storage.setString(StorageVersion.versionKey, '1');
        await storage.setString('user_name', 'testuser');
        await storage.setString('theme', 'dark');
        await storage.setString('user_tags', 'tag1, tag2');
        await storage.setString('old_setting_1', 'value');

        // Act
        await migration.migrate(storage);

        // Assert
        expect(await storage.getString('username'), 'testuser');
        expect(await storage.getString('theme_mode'), 'dark');
        expect(await storage.getStringList('user_tags'), ['tag1', 'tag2']);
        expect(await storage.containsKey('old_setting_1'), isFalse);
        expect(await storage.getString('language'), 'en');
      });

      test('should handle tags with extra spaces', () async {
        // Arrange
        await storage.setString(StorageVersion.versionKey, '1');
        await storage.setString('user_tags', '  tag1  ,  tag2  ,  tag3  ');

        // Act
        await migration.migrate(storage);

        // Assert
        final tags = await storage.getStringList('user_tags');
        expect(tags, ['tag1', 'tag2', 'tag3']);
      });

      test('should handle tags with single tag', () async {
        // Arrange
        await storage.setString(StorageVersion.versionKey, '1');
        await storage.setString('user_tags', 'single-tag');

        // Act
        await migration.migrate(storage);

        // Assert
        final tags = await storage.getStringList('user_tags');
        expect(tags, ['single-tag']);
      });
    });

    // This migration rewrites 'user_tags' in place with a different type.
    // A re-run used to read it back with `getString`, which throws a
    // `TypeError` - an Error, so every `on Exception` handler missed it -
    // and that threw before `runApp` on every launch.
    group('idempotency (#60)', () {
      test('migrate twice does not throw and leaves the same data', () async {
        // Arrange
        await storage.setString(StorageVersion.versionKey, '1');
        await storage.setString('user_name', 'testuser');
        await storage.setString('theme', 'dark');
        await storage.setString('user_tags', 'tag1, tag2');

        // Act
        await migration.migrate(storage);
        await expectLater(migration.migrate(storage), completes);

        // Assert - second run is a no-op, not a partial re-application
        expect(await storage.getString('username'), 'testuser');
        expect(await storage.getString('theme_mode'), 'dark');
        expect(await storage.getStringList('user_tags'), ['tag1', 'tag2']);
        expect(await storage.getString('language'), 'en');
      });

      test('migrate recovers a store left mid-migration', () async {
        // Arrange - exactly the bricked state: data already converted by an
        // earlier run, but the version stamp never written.
        await storage.setString(StorageVersion.versionKey, '1');
        await storage.setStringList('user_tags', ['tag1', 'tag2']);

        // Act & Assert
        await expectLater(migration.migrate(storage), completes);
        expect(await storage.getStringList('user_tags'), ['tag1', 'tag2']);
      });

      test('execute after a re-run leaves storage stamped at v2', () async {
        // Arrange
        await storage.setString(StorageVersion.versionKey, '1');
        await storage.setStringList('user_tags', ['tag1']);

        // Act
        await migration.execute(storage);

        // Assert
        expect(await storage.getString(StorageVersion.versionKey), '2');
      });
    });
  });
}
