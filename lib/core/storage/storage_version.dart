/// Storage version constants
///
/// This file defines the current storage version and version key used
/// to track the storage schema version in both regular and secure storage.
class StorageVersion {
  /// Current storage schema version
  ///
  /// Increment this when making breaking changes to storage schema
  static const int current = 2;

  /// Key used to store the version in storage
  static const String versionKey = '_storage_version';

  /// Key used to track migration status
  static const String migrationStatusKey = '_migration_status';

  /// Initial version for new installations
  static const int initial = 1;
}
