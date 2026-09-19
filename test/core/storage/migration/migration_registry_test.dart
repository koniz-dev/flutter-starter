import 'package:flutter_starter/core/storage/migration/migration_registry.dart';
import 'package:flutter_starter/core/storage/migration/migrations/migration_v1_to_v2.dart';
import 'package:flutter_starter/core/storage/migration/storage_migration.dart';
import 'package:flutter_starter/core/storage/storage_version.dart';
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
        expect(migrations.any((m) => m is MigrationV1ToV2), isTrue);
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
          expect(regularMigrations[i].runtimeType, migrations[i].runtimeType);
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
          expect(secureMigrations[i].runtimeType, migrations[i].runtimeType);
        }
      });
    });

    // Criterion 3 of #60. Bumping StorageVersion.current without registering
    // the matching migration must fail here, not on a user's device where the
    // executor throws before the first frame.
    group('chain coverage (#60)', () {
      test('migrations span initial -> current with no gap', () {
        _expectSpansVersionChain(MigrationRegistry.migrations);
      });

      test('regularStorageMigrations span initial -> current', () {
        _expectSpansVersionChain(MigrationRegistry.regularStorageMigrations);
      });

      test('secureStorageMigrations span initial -> current', () {
        _expectSpansVersionChain(MigrationRegistry.secureStorageMigrations);
      });
    });

    group('Edge Cases', () {
      test('returns an independent list on each call', () {
        // The getter builds a fresh list, so a caller that sorts or filters
        // it (MigrationExecutor sorts a copy) cannot corrupt the registry.
        final first = MigrationRegistry.migrations..clear();
        final second = MigrationRegistry.migrations;

        expect(first, isEmpty);
        expect(second, isNotEmpty);
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

/// Walk [migrations] from [StorageVersion.initial] and assert the chain
/// lands exactly on [StorageVersion.current].
void _expectSpansVersionChain(List<StorageMigration> migrations) {
  final byFromVersion = <int, StorageMigration>{};
  for (final migration in migrations) {
    expect(
      byFromVersion.containsKey(migration.fromVersion),
      isFalse,
      reason:
          'two migrations both start at v${migration.fromVersion}; the '
          'executor would pick one of them arbitrarily',
    );
    byFromVersion[migration.fromVersion] = migration;
  }

  var version = StorageVersion.initial;
  while (version < StorageVersion.current) {
    final step = byFromVersion[version];
    expect(
      step,
      isNotNull,
      reason:
          'no migration registered from v$version, so a device stamped '
          'v$version can never reach v${StorageVersion.current}',
    );
    expect(
      step!.toVersion,
      greaterThan(version),
      reason: 'migration from v$version does not advance the version',
    );
    version = step.toVersion;
  }

  expect(
    version,
    StorageVersion.current,
    reason:
        'the chain overshoots StorageVersion.current '
        '(${StorageVersion.current}) and stops at v$version',
  );
}
