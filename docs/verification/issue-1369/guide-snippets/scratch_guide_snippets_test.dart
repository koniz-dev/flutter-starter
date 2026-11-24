// Scratch: the storage-migration guide's dart fences, assembled verbatim
// (fences 0, 3, 4, 5, 6, 7, 8, 9, 11, 16) so they are analyzed, plus a
// behavioural test of the guide's complete example on SecureStorageService.
// The pattern fences are wrapped in functions nothing calls.
// ignore_for_file: unused_element
import 'package:flutter/services.dart';
import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/storage/migration/storage_migration.dart';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/storage/storage_version.dart';
import 'package:flutter_test/flutter_test.dart';

// fence 3

/// Reads [key]; a failed read throws instead of looking like a missing key.
Future<String?> readLegacy(IStorageService storage, String key) async {
  if (storage is! IStrictStringRead) return await storage.getString(key);
  try {
    return await (storage as IStrictStringRead).getStringOrThrow(key);
  } on Object catch (error, stackTrace) {
    throw MigrationException(
      'Could not read $key; not advancing the schema',
      originalError: error,
      stackTrace: stackTrace,
    );
  }
}

/// Whether [key] is stored; a failed read throws instead of answering false.
Future<bool> hasLegacy(IStorageService storage, String key) async {
  if (storage is IStrictStringRead) {
    return await readLegacy(storage, key) != null;
  }
  return await storage.containsKey(key);
}
// fence 0

class MigrationV2ToV3 extends StorageMigration {
  @override
  int get fromVersion => 2;

  @override
  int get toVersion => 3;

  @override
  String get description => 'Migrate user settings to new format';

  @override
  Future<void> migrate(IStorageService storage) async {
    // Your migration logic here
    // Example: Rename a key. Read legacy keys through readLegacy - see
    // "Reading Legacy Values" below.
    final oldValue = await readLegacy(storage, 'old_key');
    if (oldValue != null) {
      await storage.setString('new_key', oldValue);
      await storage.remove('old_key');
    }
  }
}

// fence 7
Future<String?> _readLegacyString(IStorageService storage, String key) async {
  try {
    return await readLegacy(storage, key);
  } on CacheException catch (error) {
    if (error.code != invalidPreferenceTypeCode) rethrow;
    return null; // already converted by an earlier run
    // A backend that casts the stored value blindly throws TypeError instead.
    // ignore: avoid_catching_errors
  } on TypeError {
    return null;
  }
}

// fence 16
class MigrationV1ToV2 extends StorageMigration {
  @override
  int get fromVersion => 1;

  @override
  int get toVersion => 2;

  @override
  String get description => 'Migrate user preferences to new format';

  @override
  Future<void> migrate(IStorageService storage) async {
    // 1. Rename key
    final oldUserName = await readLegacy(storage, 'user_name');
    if (oldUserName != null) {
      await storage.setString('username', oldUserName);
      await storage.remove('user_name');
    }

    // 2. Transform data
    final oldTheme = await readLegacy(storage, 'theme');
    if (oldTheme != null) {
      final newTheme = _transformTheme(oldTheme);
      await storage.setString('theme_mode', newTheme);
      await storage.remove('theme');
    }

    // 3. Add defaults (never for a user choice; see "Adding Default Values")
    if (!await hasLegacy(storage, 'sync_interval_minutes')) {
      await storage.setInt('sync_interval_minutes', 15);
    }

    // 4. Clean up deprecated keys
    await storage.remove('deprecated_key');
  }

  String _transformTheme(String oldTheme) {
    switch (oldTheme.toLowerCase()) {
      case 'dark':
        return 'dark';
      case 'light':
        return 'light';
      default:
        return 'system';
    }
  }
}

// fence 4
Future<void> _pattern4(IStorageService storage) async {
  final oldValue = await readLegacy(storage, 'old_key');
  if (oldValue != null) {
    await storage.setString('new_key', oldValue);
    await storage.remove('old_key');
  }
}

// fence 5
Future<void> _pattern5(IStorageService storage) async {
  final oldTheme = await readLegacy(storage, 'theme');
  if (oldTheme != null) {
    String newTheme;
    switch (oldTheme.toLowerCase()) {
      case 'dark':
        newTheme = 'dark';
      case 'light':
        newTheme = 'light';
      default:
        newTheme = 'system';
    }
    await storage.setString('theme_mode', newTheme);
    await storage.remove('theme');
  }
}

// fence 6
Future<void> _pattern6(IStorageService storage) async {
  final oldTags = await readLegacy(storage, 'user_tags');
  if (oldTags != null) {
    await storage.setStringList(
      'tags',
      oldTags.split(',').map((e) => e.trim()).toList(),
    );
    await storage.remove('user_tags');
  }
}

// fence 8
Future<void> _pattern8(IStorageService storage) async {
  final hasSyncInterval = await hasLegacy(storage, 'sync_interval_minutes');
  if (!hasSyncInterval) {
    await storage.setInt('sync_interval_minutes', 15);
  }
}

// fence 9
Future<void> _pattern9(IStorageService storage) async {
  final deprecatedKeys = ['old_setting_1', 'old_setting_2'];
  for (final key in deprecatedKeys) {
    if (await hasLegacy(storage, key)) {
      await storage.remove(key);
    }
  }
}

// fence 11
Future<void> _pattern11(IStorageService storage) async {
  final value = await readLegacy(storage, 'key');
  if (value != null) {
    // Process value
  }
}

const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final backing = <String, String>{};
  String? failingKey;

  setUp(() {
    backing
      ..clear()
      ..addAll({StorageVersion.versionKey: '1', 'user_name': 'alice'});
    failingKey = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          final args = call.arguments as Map<Object?, Object?>?;
          final key = args?['key'] as String? ?? '';
          switch (call.method) {
            case 'read':
              if (key == failingKey) {
                throw PlatformException(code: 'BadPaddingException');
              }
              return backing[key];
            case 'write':
              backing[key] = args?['value'] as String? ?? '';
              return null;
            case 'delete':
              backing.remove(key);
              return null;
          }
          return null;
        });
  });

  test('guide example: a failed read throws and keeps the stamp at 1, a '
      'healthy rerun migrates', () async {
    failingKey = 'user_name';
    await expectLater(
      MigrationV1ToV2().execute(SecureStorageService()),
      throwsA(isA<MigrationException>()),
    );
    expect(backing[StorageVersion.versionKey], '1');
    expect(backing['user_name'], 'alice');

    failingKey = null;
    await MigrationV1ToV2().execute(SecureStorageService());
    expect(backing[StorageVersion.versionKey], '2');
    expect(backing['username'], 'alice');
    expect(backing.containsKey('user_name'), isFalse);
  });

  test('guide helpers: hasLegacy throws on a failed read', () async {
    failingKey = 'sync_interval_minutes';
    await expectLater(
      hasLegacy(SecureStorageService(), 'sync_interval_minutes'),
      throwsA(isA<MigrationException>()),
    );
  });
}
