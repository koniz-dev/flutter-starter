import 'package:flutter_starter/core/errors/exceptions.dart';
import 'package:flutter_starter/core/storage/migration/storage_migration.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/storage/string_list_encoding.dart';

/// Example migration from version 1 to version 2
///
/// This migration demonstrates the migration pattern:
/// - Renaming keys
/// - Transforming data formats
/// - Cleaning up deprecated keys
/// - Adding new default values
///
/// **Note**: This is an example migration. Modify it based on your actual
/// storage schema changes.
class MigrationV1ToV2 extends StorageMigration {
  @override
  int get fromVersion => 1;

  @override
  int get toVersion => 2;

  @override
  String get description =>
      'Migrate user preferences: rename keys and update data format';

  @override
  Future<void> migrate(IStorageService storage) async {
    // Example 1: Rename a key
    // Old key: 'user_name' -> New key: 'username'
    final oldUserName = await storage.getString('user_name');
    if (oldUserName != null) {
      await _requirePersisted(
        storage.setString('username', oldUserName),
        'username',
      );
      await _requirePersisted(storage.remove('user_name'), 'user_name');
    }

    // Example 2: Transform data format
    // Old: 'theme' as string -> New: 'theme_mode' as string with validation
    final oldTheme = await storage.getString('theme');
    if (oldTheme != null) {
      // Transform old theme values to new format
      String newTheme;
      switch (oldTheme.toLowerCase()) {
        case 'dark':
          newTheme = 'dark';
        case 'light':
          newTheme = 'light';
        default:
          newTheme = 'system'; // Default for unknown values
      }
      await _requirePersisted(
        storage.setString('theme_mode', newTheme),
        'theme_mode',
      );
      await _requirePersisted(storage.remove('theme'), 'theme');
    }

    // Example 3: Migrate list data
    // Old: comma-separated string -> New: proper string list
    //
    // This rewrites 'user_tags' in place with a *different type*, so the read
    // has to tolerate a value that is already a list - see
    // [_readLegacyString]. Without that guard a second run throws and the app
    // cannot start. Prefer renaming the key (examples 1 and 2) when the type
    // changes; keep this shape only if you also keep the guard.
    final oldTags = await _readLegacyString(storage, 'user_tags');
    // On a string-only backend (secure storage) an already-migrated list
    // reads back through getString as its stored encoding. Splitting that on
    // commas would fragment it, so a value that is already an encoded list is
    // left alone.
    if (oldTags != null && decodeEncodedStringList(oldTags) == null) {
      final tagsList = oldTags.isEmpty
          ? <String>[]
          : oldTags.split(',').map((e) => e.trim()).toList();
      await _requirePersisted(
        storage.setStringList('user_tags', tagsList),
        'user_tags',
      );
    }

    // Example 4: Add default values for new keys
    // Only set if key doesn't exist.
    //
    // Seed only keys whose absence means "not set up yet", never a user
    // choice. This used to seed `language = 'en'`: a fresh install is stamped
    // v1, so it ran on every first launch, and `language` is the key
    // LocalizationService reads as the user's pick - so the device language
    // lost to an English preference nobody had made.
    final hasSyncInterval = await storage.containsKey('sync_interval_minutes');
    if (!hasSyncInterval) {
      await _requirePersisted(
        storage.setInt('sync_interval_minutes', 15),
        'sync_interval_minutes',
      );
    }

    // Example 5: Clean up deprecated keys
    final deprecatedKeys = ['old_setting_1', 'old_setting_2', 'deprecated_key'];

    for (final key in deprecatedKeys) {
      if (await storage.containsKey(key)) {
        await _requirePersisted(storage.remove(key), key);
      }
    }

    // Example 6: Migrate nested data structure
    // If you stored JSON strings, parse and restructure them
    final oldUserData = await storage.getString('user_data');
    if (oldUserData != null) {
      try {
        // Example: Parse old JSON and restructure
        // This is just an example - adjust based on your actual data structure
        // final userData = jsonDecode(oldUserData) as Map<String, dynamic>;
        // await storage.setString('user_id', userData['id'].toString());
        // await storage.setString('user_email', userData['email']);
        // await storage.remove('user_data');
      } on Exception {
        // If parsing fails, remove corrupted data
        await _requirePersisted(storage.remove('user_data'), 'user_data');
      }
    }
  }

  // Never delete a source key or advance the schema after a rejected write.
  // Secure storage reports platform failures as false rather than throwing.
  Future<void> _requirePersisted(Future<bool> result, String key) async {
    if (!await result) {
      throw MigrationException('Storage rejected migration mutation of $key');
    }
  }

  /// Reads a legacy string, skipping a value already stored as another type.
  ///
  /// Re-runs see a `List<String>` under 'user_tags'. StorageService reports
  /// that expected type mismatch as a coded CacheException; older/custom
  /// backends may still throw TypeError. Other read failures must propagate
  /// so an unreadable legacy value cannot be skipped while advancing schema.
  Future<String?> _readLegacyString(IStorageService storage, String key) async {
    try {
      return await storage.getString(key);
    } on CacheException catch (error) {
      if (error.code != invalidPreferenceTypeCode) rethrow;
      return null;
      // Backward compatibility for a backend that still casts blindly.
      // ignore: avoid_catching_errors
    } on TypeError {
      return null;
    }
  }
}
