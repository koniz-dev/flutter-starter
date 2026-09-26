import 'package:flutter/services.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/storage/migration/migration_executor.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_migration_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/storage/storage_version.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _secureChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('StorageMigrationService', () {
    late StorageService storageService;
    late SecureStorageService secureStorageService;
    late LoggingService loggingService;
    final secureBacking = <String, String>{};

    /// Install a working in-memory Keychain.
    ///
    /// Without this the plugin channel is unimplemented, every secure write
    /// is swallowed into `false`, and the migration cannot stamp a version -
    /// which the executor now (correctly) reports as a failure.
    void installSecureBackend() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_secureChannel, (methodCall) async {
            final arguments = methodCall.arguments as Map<Object?, Object?>?;
            final key = arguments?['key'] as String? ?? '';
            switch (methodCall.method) {
              case 'read':
                return secureBacking[key];
              case 'write':
                secureBacking[key] = arguments?['value'] as String? ?? '';
                return null;
              case 'delete':
                secureBacking.remove(key);
                return null;
              case 'deleteAll':
                secureBacking.clear();
                return null;
              default:
                return null;
            }
          });
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storageService = StorageService();
      await storageService.init();
      secureBacking.clear();
      installSecureBackend();
      secureStorageService = SecureStorageService();
      loggingService = LoggingService(enableLogging: false);
    });

    tearDown(() async {
      await storageService.clear();
      secureBacking.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_secureChannel, null);
    });

    test(
      'migrateAll leaves both stores stamped at the current version',
      () async {
        final migrationService = StorageMigrationService(
          storageService: storageService,
          secureStorageService: secureStorageService,
          loggingService: loggingService,
        );

        final results = await migrationService.migrateAll();

        // The returned versions used to be asserted only as "not null", which
        // held even when migration silently did nothing (#60).
        expect(results['regular'], StorageVersion.current);
        expect(results['secure'], StorageVersion.current);
        expect(
          await storageService.getString(StorageVersion.versionKey),
          '${StorageVersion.current}',
        );
        expect(
          await secureStorageService.getString(StorageVersion.versionKey),
          '${StorageVersion.current}',
        );
      },
    );

    test(
      'migrateRegular executes migrations for regular storage only',
      () async {
        final migrationService = StorageMigrationService(
          storageService: storageService,
          secureStorageService: secureStorageService,
          loggingService: loggingService,
        );

        final result = await migrationService.migrateRegular();

        expect(result, StorageVersion.current);
        expect(
          await storageService.getString(StorageVersion.versionKey),
          '${StorageVersion.current}',
        );
      },
    );

    test('migrateSecure executes migrations for secure storage only', () async {
      final migrationService = StorageMigrationService(
        storageService: storageService,
        secureStorageService: secureStorageService,
        loggingService: loggingService,
      );

      final result = await migrationService.migrateSecure();

      expect(result, StorageVersion.current);
      expect(
        await secureStorageService.getString(StorageVersion.versionKey),
        '${StorageVersion.current}',
      );
    });

    // Criterion 5 of #60: SecureStorageService returns false instead of
    // throwing when the backend is unavailable, so the version stamp write
    // used to fail in silence and the chain re-ran on every launch.
    test('migrateSecure surfaces an unwritable secure backend', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_secureChannel, null);

      final migrationService = StorageMigrationService(
        storageService: storageService,
        secureStorageService: secureStorageService,
        loggingService: loggingService,
      );

      await expectLater(
        migrationService.migrateSecure(),
        throwsA(isA<MigrationExecutionException>()),
      );
    });
  });
}
