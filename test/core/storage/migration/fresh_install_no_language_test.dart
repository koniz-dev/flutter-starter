// A fresh install must not get a stored language it never chose
// (koniz-dev/flutter-starter#417).
//
// The example MigrationV1ToV2 seeded `language = 'en'` whenever the key was
// absent. A fresh install is stamped v1, so it ran on every first launch, and
// MigrationRegistry applies it to both stores. `language` is the key
// LocalizationService reads as the user's choice, so the device language
// (#324) lost to an English "preference" nobody had set.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/core/localization/localization_service.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
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

  final keychain = <String, String>{};

  setUp(() {
    keychain.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, (call) async {
          final args = call.arguments as Map<Object?, Object?>?;
          final key = args?['key'] as String? ?? '';
          switch (call.method) {
            case 'read':
              return keychain[key];
            case 'write':
              keychain[key] = args?['value'] as String? ?? '';
              return null;
            case 'delete':
              keychain.remove(key);
              return null;
            case 'readAll':
              return Map<String, String>.of(keychain);
            case 'containsKey':
              return keychain.containsKey(key);
            case 'deleteAll':
              keychain.clear();
              return null;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, null);
  });

  test('a fresh boot writes no language key to either store', () async {
    final storage = StorageService();
    await storage.init();
    final service = StorageMigrationService(
      storageService: storage,
      secureStorageService: SecureStorageService(),
      loggingService: LoggingService(enableLogging: false),
    );

    final versions = await service.migrateAll();

    final prefs = await SharedPreferences.getInstance();
    final stored = {for (final k in prefs.getKeys()) k: prefs.get(k)};
    // ignore: avoid_print - the evidence line for the criterion
    print('VM versions=$versions prefs=$stored keychain=$keychain');

    // The migration really ran on both stores...
    expect(versions['regular'], StorageVersion.current);
    expect(versions['secure'], StorageVersion.current);
    expect(stored[StorageVersion.versionKey], '${StorageVersion.current}');
    // ...and left no language choice behind in either.
    expect(stored.containsKey(AppConstants.languageKey), isFalse);
    expect(keychain.containsKey(AppConstants.languageKey), isFalse);
  });

  test('a language the user did choose survives the migration', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.languageKey: 'vi',
      StorageVersion.versionKey: '1',
    });
    final storage = StorageService();
    await storage.init();
    final service = StorageMigrationService(
      storageService: storage,
      secureStorageService: SecureStorageService(),
      loggingService: LoggingService(enableLogging: false),
    );

    await service.migrateAll();

    expect(await storage.getString(AppConstants.languageKey), 'vi');
  });

  testWidgets('after a fresh boot, a vi device resolves to vi (#324 + #417)', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('vi', 'VN')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final storage = StorageService();
    await tester.runAsync(() async {
      await storage.init();
      await StorageMigrationService(
        storageService: storage,
        secureStorageService: SecureStorageService(),
        loggingService: LoggingService(enableLogging: false),
      ).migrateAll();
    });

    final locale = await tester.runAsync(
      () => LocalizationService(storageService: storage).getCurrentLocale(),
    );

    expect(locale, SupportedLocale.vi.locale);
  });
}
