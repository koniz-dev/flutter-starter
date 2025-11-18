import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/storage/migration/storage_migration.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/storage/storage_version.dart';

/// Executes storage migrations in sequence
///
/// This class is responsible for:
/// - Detecting the current storage version
/// - Finding and executing applicable migrations
/// - Handling errors during migration
/// - Logging migration activities
///
/// Usage:
/// ```dart
/// final executor = MigrationExecutor(
///   storage: storageService,
///   loggingService: loggingService,
///   migrations: [MigrationV1ToV2(), MigrationV2ToV3()],
/// );
/// await executor.execute();
/// ```
class MigrationExecutor {
  /// Creates a [MigrationExecutor] instance
  ///
  /// [storage] - The storage service to migrate
  /// [loggingService] - Service for logging migration activities
  /// [migrations] - List of migrations to execute
  /// (should be ordered by version)
  MigrationExecutor({
    required this.storage,
    required this.loggingService,
    required this.migrations,
  }) {
    // Sort migrations by fromVersion to ensure correct execution order
    _sortedMigrations = List<StorageMigration>.from(migrations)
      ..sort((a, b) => a.fromVersion.compareTo(b.fromVersion));
  }

  /// The storage service to migrate
  final IStorageService storage;

  /// Logging service for migration activities
  final LoggingService loggingService;

  /// List of migrations to execute
  final List<StorageMigration> migrations;

  /// Sorted list of migrations (by fromVersion)
  late final List<StorageMigration> _sortedMigrations;

  /// Execute all applicable migrations
  ///
  /// This method:
  /// 1. Gets the current storage version
  /// 2. Finds all migrations that need to be executed
  /// 3. Executes them in sequence
  /// 4. Handles errors gracefully
  ///
  /// Returns the final version after migration
  Future<int> execute() async {
    final currentVersion = await _getCurrentVersion();
    const targetVersion = StorageVersion.current;

    loggingService.info(
      'Starting storage migration',
      context: {
        'current_version': currentVersion,
        'target_version': targetVersion,
        'migrations_count': _sortedMigrations.length,
      },
    );

    // If already at target version, no migration needed
    if (currentVersion >= targetVersion) {
      loggingService.info(
        'Storage is already at target version',
        context: {'current_version': currentVersion},
      );
      return currentVersion;
    }

    // Find migrations that need to be executed
    final applicableMigrations = _findApplicableMigrations(currentVersion);

    if (applicableMigrations.isEmpty) {
      loggingService.warning(
        'No migrations found to reach target version',
        context: {
          'current_version': currentVersion,
          'target_version': targetVersion,
        },
      );
      return currentVersion;
    }

    // Execute migrations in sequence
    for (final migration in applicableMigrations) {
      try {
        loggingService.info(
          'Executing migration: ${migration.description}',
          context: {
            'from_version': migration.fromVersion,
            'to_version': migration.toVersion,
          },
        );

        await migration.execute(storage);

        loggingService.info(
          'Migration completed successfully',
          context: {
            'from_version': migration.fromVersion,
            'to_version': migration.toVersion,
          },
        );
      } on MigrationException catch (e, stackTrace) {
        loggingService.error(
          'Migration failed: ${e.message}',
          context: {
            'from_version': migration.fromVersion,
            'to_version': migration.toVersion,
            'description': migration.description,
          },
          error: e.originalError ?? e,
          stackTrace: e.stackTrace ?? stackTrace,
        );

        // Decide whether to continue or abort
        // For now, we abort on any migration failure
        throw MigrationExecutionException(
          'Migration from v${migration.fromVersion} '
          'to v${migration.toVersion} failed',
          originalException: e,
        );
      } catch (e, stackTrace) {
        loggingService.error(
          'Unexpected error during migration',
          context: {
            'from_version': migration.fromVersion,
            'to_version': migration.toVersion,
            'description': migration.description,
          },
          error: e,
          stackTrace: stackTrace,
        );

        throw MigrationExecutionException(
          'Unexpected error during migration from '
          'v${migration.fromVersion} to v${migration.toVersion}',
          originalException: e,
        );
      }
    }

    // Verify final version
    final finalVersion = await _getCurrentVersion();
    if (finalVersion != targetVersion) {
      loggingService.warning(
        'Migration completed but version mismatch',
        context: {
          'expected_version': targetVersion,
          'actual_version': finalVersion,
        },
      );
    } else {
      loggingService.info(
        'All migrations completed successfully',
        context: {'final_version': finalVersion},
      );
    }

    return finalVersion;
  }

  /// Get the current storage version
  Future<int> _getCurrentVersion() async {
    try {
      final versionString = await storage.getString(StorageVersion.versionKey);
      if (versionString == null) {
        // First install - set initial version
        await storage.setString(
          StorageVersion.versionKey,
          StorageVersion.initial.toString(),
        );
        return StorageVersion.initial;
      }
      final version = int.tryParse(versionString);
      if (version == null || version < StorageVersion.initial) {
        // Corrupted version - reset to initial
        loggingService.warning(
          'Invalid storage version detected, resetting to initial',
          context: {'invalid_version': versionString},
        );
        await storage.setString(
          StorageVersion.versionKey,
          StorageVersion.initial.toString(),
        );
        return StorageVersion.initial;
      }
      return version;
    } on Exception catch (e, stackTrace) {
      loggingService.error(
        'Error reading storage version',
        error: e,
        stackTrace: stackTrace,
      );
      // On error, assume initial version
      return StorageVersion.initial;
    }
  }

  /// Find migrations that need to be executed to reach target version
  List<StorageMigration> _findApplicableMigrations(int currentVersion) {
    final applicable = <StorageMigration>[];
    var nextVersion = currentVersion;

    for (final migration in _sortedMigrations) {
      if (migration.fromVersion == nextVersion &&
          migration.toVersion > nextVersion) {
        applicable.add(migration);
        nextVersion = migration.toVersion;

        // If we've reached or exceeded target, stop
        if (nextVersion >= StorageVersion.current) {
          break;
        }
      }
    }

    // Check for gaps in migration chain
    if (applicable.isNotEmpty) {
      final firstMigration = applicable.first;
      if (firstMigration.fromVersion != currentVersion) {
        loggingService.warning(
          'Migration chain gap detected',
          context: {
            'current_version': currentVersion,
            'first_migration_from': firstMigration.fromVersion,
          },
        );
      }
    }

    return applicable;
  }
}

/// Exception thrown when migration execution fails
class MigrationExecutionException implements Exception {
  /// Creates a [MigrationExecutionException] with the given [message]
  MigrationExecutionException(
    this.message, {
    this.originalException,
  });

  /// Error message describing what went wrong
  final String message;

  /// Original exception that caused the failure (if any)
  final Object? originalException;

  @override
  String toString() {
    if (originalException != null) {
      return 'MigrationExecutionException: $message\n'
          'Original exception: $originalException';
    }
    return 'MigrationExecutionException: $message';
  }
}
