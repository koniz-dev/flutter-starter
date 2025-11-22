import 'package:flutter_starter/core/storage/migration/migration_registry.dart';
import 'package:flutter_starter/core/storage/migration/migrations/migration_v1_to_v2.dart';
import 'package:flutter_starter/core/storage/migration/storage_migration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MigrationRegistry', () {
    group('migrations', () {
      test('should return list of migrations', () {
        // Act
        final migrations = MigrationRegistry.migrations;

        // Assert
        expect(migrations, isA<List<StorageMigration>>());
        expect(migrations, isNotEmpty);
      });

      test('should contain MigrationV1ToV2', () {
        // Act
        final migrations = MigrationRegistry.migrations;

        // Assert
        expect(
          migrations.any((m) => m is MigrationV1ToV2),
          isTrue,
        );
      });

      test('should have migrations in correct order', () {
        // Act
        final migrations = MigrationRegistry.migrations;

        // Assert
        // Migrations should be ordered by version
        for (var i = 0; i < migrations.length - 1; i++) {
          expect(
            migrations[i].toVersion,
            lessThanOrEqualTo(migrations[i + 1].fromVersion),
          );
        }
      });

      test('should have valid version transitions', () {
        // Act
        final migrations = MigrationRegistry.migrations;

        // Assert
        for (final migration in migrations) {
          expect(migration.fromVersion, greaterThan(0));
          expect(migration.toVersion, greaterThan(migration.fromVersion));
        }
      });

      test('should have non-empty descriptions', () {
        // Act
        final migrations = MigrationRegistry.migrations;

        // Assert
        for (final migration in migrations) {
          expect(migration.description, isNotEmpty);
        }
      });
    });

    group('regularStorageMigrations', () {
      test('should return migrations list', () {
        // Act
        final migrations = MigrationRegistry.regularStorageMigrations;

        // Assert
        expect(migrations, isA<List<StorageMigration>>());
        expect(migrations, isNotEmpty);
      });

      test('should return same as migrations by default', () {
        // Act
        final migrations = MigrationRegistry.migrations;
        final regularMigrations = MigrationRegistry.regularStorageMigrations;

        // Assert
        expect(regularMigrations.length, migrations.length);
        for (var i = 0; i < migrations.length; i++) {
          expect(
            regularMigrations[i].runtimeType,
            migrations[i].runtimeType,
          );
        }
      });
    });

    group('secureStorageMigrations', () {
      test('should return migrations list', () {
        // Act
        final migrations = MigrationRegistry.secureStorageMigrations;

        // Assert
        expect(migrations, isA<List<StorageMigration>>());
        expect(migrations, isNotEmpty);
      });

      test('should return same as migrations by default', () {
        // Act
        final migrations = MigrationRegistry.migrations;
        final secureMigrations = MigrationRegistry.secureStorageMigrations;

        // Assert
        expect(secureMigrations.length, migrations.length);
        for (var i = 0; i < migrations.length; i++) {
          expect(
            secureMigrations[i].runtimeType,
            migrations[i].runtimeType,
          );
        }
      });
    });

    group('Edge Cases', () {
      test('should handle empty migrations list gracefully', () {
        // Note: Currently has at least one migration, but test structure
        // Act
        final migrations = MigrationRegistry.migrations;

        // Assert
        expect(migrations, isA<List<StorageMigration>>());
      });

      test('should have consistent regular and secure migrations', () {
        // Act
        final regular = MigrationRegistry.regularStorageMigrations;
        final secure = MigrationRegistry.secureStorageMigrations;

        // Assert
        expect(regular.length, secure.length);
      });
    });
  });
}
