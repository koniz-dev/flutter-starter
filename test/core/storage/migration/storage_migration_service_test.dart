import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_migration_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('StorageMigrationService', () {
    late StorageService storageService;
    late SecureStorageService secureStorageService;
    late LoggingService loggingService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storageService = StorageService();
      await storageService.init();
      secureStorageService = SecureStorageService();
      loggingService = LoggingService(enableLogging: false);
    });

    tearDown(() async {
      await storageService.clear();
      await secureStorageService.clear();
    });

    test('migrateAll executes migrations for both storage types', () async {
      final migrationService = StorageMigrationService(
        storageService: storageService,
        secureStorageService: secureStorageService,
        loggingService: loggingService,
      );

      final results = await migrationService.migrateAll();

      expect(results, contains('regular'));
      expect(results, contains('secure'));
      expect(results['regular'], isNotNull);
      expect(results['secure'], isNotNull);
    });

    test('migrateRegular executes migrations for regular storage only',
        () async {
      final migrationService = StorageMigrationService(
        storageService: storageService,
        secureStorageService: secureStorageService,
        loggingService: loggingService,
      );

      final result = await migrationService.migrateRegular();

      expect(result, isNotNull);
      expect(result, greaterThanOrEqualTo(1));
    });

    test('migrateSecure executes migrations for secure storage only', () async {
      final migrationService = StorageMigrationService(
        storageService: storageService,
        secureStorageService: secureStorageService,
        loggingService: loggingService,
      );

      final result = await migrationService.migrateSecure();

      expect(result, isNotNull);
      expect(result, greaterThanOrEqualTo(1));
    });
  });
}
