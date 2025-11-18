import 'package:flutter_starter/core/storage/migration/migrations/migration_v1_to_v2.dart';
import 'package:flutter_starter/core/storage/migration/storage_migration.dart';
import 'package:flutter_starter/core/storage/storage_version.dart';

/// Registry of all storage migrations
///
/// This class centralizes all migrations in one place, making it easy to:
/// - See all available migrations at a glance
/// - Add new migrations
/// - Ensure migrations are in the correct order
///
/// To add a new migration:
/// 1. Create a new migration class extending [StorageMigration]
/// 2. Add it to the [migrations] list in the correct order
/// 3. Update [StorageVersion.current] to the new version
class MigrationRegistry {
  /// Get all registered migrations
  ///
  /// Migrations should be ordered by version (v1->v2, v2->v3, etc.)
  /// The executor will automatically sort them, but keeping them ordered
  /// here makes the code more readable.
  static List<StorageMigration> get migrations => [
        // Add migrations in order
        MigrationV1ToV2(),
        // MigrationV2ToV3(),
        // MigrationV3ToV4(),
        // ... add more migrations as needed
      ];

  /// Get migrations for regular storage (non-sensitive data)
  ///
  /// Some migrations might only apply to regular storage or secure storage.
  /// Override this method if you need different migrations for each.
  static List<StorageMigration> get regularStorageMigrations => migrations;

  /// Get migrations for secure storage (sensitive data)
  ///
  /// Some migrations might only apply to regular storage or secure storage.
  /// Override this method if you need different migrations for each.
  static List<StorageMigration> get secureStorageMigrations => migrations;
}
