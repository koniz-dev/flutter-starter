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
  ///
  /// [targetVersion] defaults to [StorageVersion.current] and exists so tests
  /// can exercise chains longer than the one this build ships.
  MigrationExecutor({
    required this.storage,
    required this.loggingService,
    required this.migrations,
    this.targetVersion = StorageVersion.current,
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

  /// Version the storage must end up at
  final int targetVersion;

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

    loggingService.info(
      'Starting storage migration',
      context: {
        'current_version': currentVersion,
        'target_version': targetVersion,
        'migrations_count': _sortedMigrations.length,
      },
    );

    // If already at target version, no migration needed
    if (currentVersion == targetVersion) {
      loggingService.info(
        'Storage is already at target version',
        context: {'current_version': currentVersion},
      );
      return currentVersion;
    }

    // Stored data is NEWER than this build understands (for example a beta
    // build stamped v3, then production v2 is installed over it). There is no
    // safe way to read v3-shaped data with v2 code, and silently returning
    // here would do exactly that. Reported separately from
    // "already up to date" so the caller can tell the two apart.
    if (currentVersion > targetVersion) {
      loggingService.error(
        'Storage version is newer than this build supports',
        context: {
          'current_version': currentVersion,
          'target_version': targetVersion,
        },
      );
      throw StorageDowngradeException(
        'Stored data is at version $currentVersion but this build only '
        'supports version $targetVersion. Refusing to read newer data with '
        'older code.',
        storedVersion: currentVersion,
        supportedVersion: targetVersion,
      );
    }

    // Build the full chain up front. A missing link throws rather than
    // migrating part of the way and reporting success.
    final applicableMigrations = _planMigrations(currentVersion);

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

    // Verify final version. Reaching this point with the wrong stamp means a
    // version write was accepted by the storage backend but did not stick -
    // on the next launch the whole chain would run again over already
    // migrated data, so this is a failure, not a warning.
    final finalVersion = await _getCurrentVersion();
    if (finalVersion != targetVersion) {
      loggingService.error(
        'Migration completed but version mismatch',
        context: {
          'expected_version': targetVersion,
          'actual_version': finalVersion,
        },
      );
      throw MigrationExecutionException(
        'Migrations ran but storage is stamped v$finalVersion instead of '
        'v$targetVersion. The version stamp was not persisted.',
      );
    }

    loggingService.info(
      'All migrations completed successfully',
      context: {'final_version': finalVersion},
    );

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

  /// Build the ordered chain of migrations from [currentVersion] to
  /// [targetVersion].
  ///
  /// Throws [MigrationPathException] when the chain cannot be completed -
  /// either because nothing is registered for some intermediate version, or
  /// because a registered migration jumps past [targetVersion]. Returning a
  /// partial chain instead would let the app start on half-migrated data.
  List<StorageMigration> _planMigrations(int currentVersion) {
    final planned = <StorageMigration>[];
    var nextVersion = currentVersion;

    while (nextVersion < targetVersion) {
      final step = _migrationFrom(nextVersion);

      if (step == null) {
        loggingService.error(
          'No migration registered for the stored storage version',
          context: {
            'current_version': currentVersion,
            'target_version': targetVersion,
            'missing_from_version': nextVersion,
          },
        );
        throw MigrationPathException(
          'No migration path from v$currentVersion to v$targetVersion: '
          'nothing is registered to migrate from v$nextVersion.',
          currentVersion: currentVersion,
          targetVersion: targetVersion,
          missingFromVersion: nextVersion,
        );
      }

      if (step.toVersion > targetVersion) {
        loggingService.error(
          'Registered migration overshoots the target storage version',
          context: {
            'current_version': currentVersion,
            'target_version': targetVersion,
            'from_version': step.fromVersion,
            'to_version': step.toVersion,
          },
        );
        throw MigrationPathException(
          'No migration path from v$currentVersion to v$targetVersion: the '
          'migration from v${step.fromVersion} jumps to v${step.toVersion}, '
          'past the target.',
          currentVersion: currentVersion,
          targetVersion: targetVersion,
          missingFromVersion: nextVersion,
        );
      }

      planned.add(step);
      nextVersion = step.toVersion;
    }

    return planned;
  }

  /// The first registered migration starting at [fromVersion], or null.
  StorageMigration? _migrationFrom(int fromVersion) {
    for (final migration in _sortedMigrations) {
      if (migration.fromVersion == fromVersion &&
          migration.toVersion > fromVersion) {
        return migration;
      }
    }
    return null;
  }
}

/// Exception thrown when migration execution fails
class MigrationExecutionException implements Exception {
  /// Creates a [MigrationExecutionException] with the given [message]
  MigrationExecutionException(this.message, {this.originalException});

  /// Error message describing what went wrong
  final String message;

  /// Original exception that caused the failure (if any)
  final Object? originalException;

  /// Name this exception introduces itself by in [toString].
  ///
  /// Subclasses override it so they do not inherit this class's name. Spelled
  /// out rather than taken from `runtimeType`, because the release builds in
  /// `docs/guides/security/implementation.md` pass `--obfuscate`, which would
  /// reduce `runtimeType` to a minified token in exactly the situation this
  /// string exists for.
  String get exceptionName => 'MigrationExecutionException';

  /// A readable description carrying the concrete type and the message.
  ///
  /// `main()` renders `'$error'` straight into `StartupFailureApp`, so this is
  /// the first thing a user - and a bug report - sees when a startup migration
  /// fails. A downgrade refusal that called itself a
  /// `MigrationExecutionException` was the wrong diagnosis.
  @override
  String toString() {
    if (originalException != null) {
      return '$exceptionName: $message\n'
          'Original exception: $originalException';
    }
    return '$exceptionName: $message';
  }
}

/// Exception thrown when no complete migration chain reaches the target
/// version
///
/// This is the "missing migration" case: storage is behind
/// [StorageVersion.current] and either nothing is registered for some
/// intermediate version, or a registered migration jumps past the target.
class MigrationPathException extends MigrationExecutionException {
  /// Creates a [MigrationPathException] with the given [message]
  MigrationPathException(
    super.message, {
    required this.currentVersion,
    required this.targetVersion,
    required this.missingFromVersion,
  });

  /// Version currently stamped in storage
  final int currentVersion;

  /// Version the app expects storage to be at
  final int targetVersion;

  /// Version the chain could not be continued from
  final int missingFromVersion;

  @override
  String get exceptionName => 'MigrationPathException';
}

/// Exception thrown when storage is stamped with a version newer than this
/// build supports
///
/// Distinct from "already at target version": the data on disk was written by
/// a newer build and cannot be safely read by this one.
class StorageDowngradeException extends MigrationExecutionException {
  /// Creates a [StorageDowngradeException] with the given [message]
  StorageDowngradeException(
    super.message, {
    required this.storedVersion,
    required this.supportedVersion,
  });

  /// Version currently stamped in storage
  final int storedVersion;

  /// Highest version this build understands
  final int supportedVersion;

  @override
  String get exceptionName => 'StorageDowngradeException';
}
