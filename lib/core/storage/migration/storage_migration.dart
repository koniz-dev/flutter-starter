import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/storage/storage_version.dart';

/// Abstract base class for storage migrations
///
/// Each migration should extend this class and implement the [migrate] method
/// to transform data from the previous version to the target version.
///
/// Example:
/// ```dart
/// class MigrationV1ToV2 extends StorageMigration {
///   @override
///   int get fromVersion => 1;
///
///   @override
///   int get toVersion => 2;
///
///   @override
///   String get description => 'Migrate user preferences to new format';
///
///   @override
///   Future<void> migrate(IStorageService storage) async {
///     // Migration logic here
///   }
/// }
/// ```
abstract class StorageMigration {
  /// The version this migration migrates from
  int get fromVersion;

  /// The version this migration migrates to
  int get toVersion;

  /// Human-readable description of what this migration does
  String get description;

  /// Execute the migration
  ///
  /// [storage] - The storage service to migrate
  ///
  /// Throws [MigrationException] if migration fails
  Future<void> migrate(IStorageService storage);

  /// Validate that the migration can be safely executed
  ///
  /// Override this method to add custom validation logic.
  /// By default, it checks that the storage version matches [fromVersion].
  ///
  /// Returns true if migration can proceed, false otherwise
  Future<bool> canMigrate(IStorageService storage) async {
    final currentVersion = await _getCurrentVersion(storage);
    return currentVersion == fromVersion;
  }

  /// Get the current storage version
  Future<int> _getCurrentVersion(IStorageService storage) async {
    final versionString = await storage.getString(StorageVersion.versionKey);
    if (versionString == null) {
      return StorageVersion.initial;
    }
    return int.tryParse(versionString) ?? StorageVersion.initial;
  }

  /// Set the storage version after successful migration
  Future<void> _setVersion(IStorageService storage, int version) async {
    await storage.setString(StorageVersion.versionKey, version.toString());
  }

  /// Execute migration with validation and version update
  ///
  /// This is the main entry point called by the migration executor.
  /// It validates, executes the migration, and updates the version.
  Future<void> execute(IStorageService storage) async {
    final canProceed = await canMigrate(storage);
    if (!canProceed) {
      throw MigrationException(
        'Cannot migrate from version $fromVersion. '
        'Current version does not match expected version.',
      );
    }

    await migrate(storage);
    await _setVersion(storage, toVersion);
  }
}

/// Exception thrown when a migration fails
class MigrationException implements Exception {
  /// Creates a [MigrationException] with the given [message]
  MigrationException(this.message, {this.originalError, this.stackTrace});

  /// Error message describing what went wrong
  final String message;

  /// Original error that caused the migration to fail (if any)
  final Object? originalError;

  /// Stack trace of the original error (if any)
  final StackTrace? stackTrace;

  @override
  String toString() {
    if (originalError != null) {
      return 'MigrationException: $message\nOriginal error: $originalError';
    }
    return 'MigrationException: $message';
  }
}
