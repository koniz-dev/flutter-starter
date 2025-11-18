import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/storage/migration/migration_executor.dart';
import 'package:flutter_starter/core/storage/migration/migration_registry.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';

/// Service for managing storage migrations
///
/// This service coordinates migrations for both regular and secure storage.
/// It should be called during app initialization to ensure all storage
/// is migrated to the current schema version.
///
/// Usage:
/// ```dart
/// final migrationService = StorageMigrationService(
///   storageService: storageService,
///   secureStorageService: secureStorageService,
///   loggingService: loggingService,
/// );
/// await migrationService.migrateAll();
/// ```
class StorageMigrationService {
  /// Creates a [StorageMigrationService] instance
  ///
  /// [storageService] - Service for non-sensitive data
  /// [secureStorageService] - Service for sensitive data
  /// [loggingService] - Service for logging migration activities
  StorageMigrationService({
    required this.storageService,
    required this.secureStorageService,
    required this.loggingService,
  });

  /// Service for non-sensitive data (SharedPreferences)
  final StorageService storageService;

  /// Service for sensitive data (flutter_secure_storage)
  final SecureStorageService secureStorageService;

  /// Logging service for migration activities
  final LoggingService loggingService;

  /// Execute migrations for both storage services
  ///
  /// This method:
  /// 1. Initializes both storage services
  /// 2. Executes migrations for regular storage
  /// 3. Executes migrations for secure storage
  /// 4. Handles errors gracefully
  ///
  /// Returns a map with migration results for each storage type
  Future<Map<String, int>> migrateAll() async {
    final results = <String, int>{};

    try {
      // Initialize storage services
      await storageService.init();

      // Migrate regular storage
      loggingService.info('Starting regular storage migration');
      final regularMigrations = MigrationRegistry.regularStorageMigrations;
      final regularExecutor = MigrationExecutor(
        storage: storageService,
        loggingService: loggingService,
        migrations: regularMigrations,
      );
      results['regular'] = await regularExecutor.execute();

      // Migrate secure storage
      loggingService.info('Starting secure storage migration');
      final secureMigrations = MigrationRegistry.secureStorageMigrations;
      final secureExecutor = MigrationExecutor(
        storage: secureStorageService,
        loggingService: loggingService,
        migrations: secureMigrations,
      );
      results['secure'] = await secureExecutor.execute();

      loggingService.info(
        'All storage migrations completed',
        context: results,
      );
    } catch (e, stackTrace) {
      loggingService.error(
        'Storage migration failed',
        error: e,
        stackTrace: stackTrace,
        context: {
          'regular_version': results['regular'],
          'secure_version': results['secure'],
        },
      );
      // Re-throw to allow caller to handle
      rethrow;
    }

    return results;
  }

  /// Execute migrations for regular storage only
  Future<int> migrateRegular() async {
    await storageService.init();
    final migrations = MigrationRegistry.regularStorageMigrations;
    final executor = MigrationExecutor(
      storage: storageService,
      loggingService: loggingService,
      migrations: migrations,
    );
    return executor.execute();
  }

  /// Execute migrations for secure storage only
  Future<int> migrateSecure() async {
    final migrations = MigrationRegistry.secureStorageMigrations;
    final executor = MigrationExecutor(
      storage: secureStorageService,
      loggingService: loggingService,
      migrations: migrations,
    );
    return executor.execute();
  }
}
