// A failed legacy-key read is not a missing key.
//
// SecureStorageService.getString returns null and containsKey returns false
// when the Keychain/Keystore read throws. MigrationV1ToV2 read its legacy keys
// that way, so one unreadable key was taken as "nothing to migrate", the
// stamp moved to v2, and the legacy value was never migrated. These tests
// drive the real SecureStorageService over a mocked plugin channel where only
// one key's read fails.

import 'package:flutter/services.dart';
import 'package:flutter_starter/core/logging/logging_service.dart';
import 'package:flutter_starter/core/storage/migration/migration_executor.dart';
import 'package:flutter_starter/core/storage/migration/migrations/migration_v1_to_v2.dart';
import 'package:flutter_starter/core/storage/migration/storage_migration.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_version.dart';
import 'package:flutter_test/flutter_test.dart';

const _secureChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final backing = <String, String>{};
  String? failingKey;

  setUp(() {
    backing
      ..clear()
      ..addAll({
        StorageVersion.versionKey: '1',
        'user_name': 'alice',
        'theme': 'dark',
        'user_tags': 'one,two',
        'old_setting_1': 'legacy',
        'user_data': '{}',
      });
    failingKey = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, (call) async {
          final args = call.arguments as Map<Object?, Object?>?;
          final key = args?['key'] as String? ?? '';
          switch (call.method) {
            case 'read':
              if (key == failingKey) {
                throw PlatformException(
                  code: 'Exception encountered',
                  message: 'BadPaddingException',
                );
              }
              return backing[key];
            case 'write':
              backing[key] = args?['value'] as String? ?? '';
              return null;
            case 'delete':
              backing.remove(key);
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureChannel, null);
  });

  for (final key in [
    'user_name',
    'theme',
    'user_tags',
    'sync_interval_minutes',
    'old_setting_1',
    'user_data',
  ]) {
    test('a failed read of $key throws MigrationException and keeps the '
        'stamp at 1', () async {
      failingKey = key;
      final before = Map<String, String>.of(backing);

      await expectLater(
        MigrationV1ToV2().execute(SecureStorageService()),
        throwsA(
          isA<MigrationException>().having(
            (e) => e.originalError,
            'originalError',
            isA<PlatformException>(),
          ),
        ),
      );

      expect(backing[StorageVersion.versionKey], '1');
      // The unreadable value is still there for the next launch to migrate.
      if (before.containsKey(key)) expect(backing[key], before[key]);
    });
  }

  test('through the executor, a failed user_name read leaves the stamp at 1 '
      'and the legacy value unmigrated', () async {
    failingKey = 'user_name';

    await expectLater(
      MigrationExecutor(
        storage: SecureStorageService(),
        loggingService: LoggingService(enableLogging: false),
        migrations: [MigrationV1ToV2()],
      ).execute(),
      throwsA(isA<MigrationExecutionException>()),
    );

    expect(backing[StorageVersion.versionKey], '1');
    expect(backing['user_name'], 'alice');
    expect(backing.containsKey('username'), isFalse);
  });

  test('after a failed read leaves the stamp at 1, a healthy rerun reaches 2 '
      'and migrates the data once', () async {
    failingKey = 'user_name';
    await expectLater(
      MigrationV1ToV2().execute(SecureStorageService()),
      throwsA(isA<MigrationException>()),
    );
    expect(backing[StorageVersion.versionKey], '1');

    failingKey = null;
    await MigrationV1ToV2().execute(SecureStorageService());

    expect(backing[StorageVersion.versionKey], '2');
    expect(backing['username'], 'alice');
    expect(backing.containsKey('user_name'), isFalse);
    expect(backing['theme_mode'], 'dark');
    expect(backing.containsKey('theme'), isFalse);
    expect(backing['sync_interval_minutes'], '15');
    expect(backing.containsKey('old_setting_1'), isFalse);
    // Migrated once: the comma list became one encoded list, not a list of
    // fragments of an already encoded value.
    expect(
      await SecureStorageService().getStringList('user_tags'),
      ['one', 'two'],
    );
  });

  test('control: with every read working, the migration advances to 2', () {
    return expectLater(
      MigrationV1ToV2().execute(SecureStorageService()).then((_) => backing),
      completion(
        allOf(
          containsPair(StorageVersion.versionKey, '2'),
          containsPair('username', 'alice'),
          isNot(contains('user_name')),
          isNot(contains('old_setting_1')),
          containsPair('sync_interval_minutes', '15'),
        ),
      ),
    );
  });
}
