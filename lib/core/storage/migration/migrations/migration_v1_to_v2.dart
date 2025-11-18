import 'package:flutter_starter/core/storage/migration/storage_migration.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';

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
      await storage.setString('username', oldUserName);
      await storage.remove('user_name');
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
      await storage.setString('theme_mode', newTheme);
      await storage.remove('theme');
    }

    // Example 3: Migrate list data
    // Old: comma-separated string -> New: proper string list
    final oldTags = await storage.getString('user_tags');
    if (oldTags != null && oldTags.isNotEmpty) {
      final tagsList = oldTags.split(',').map((e) => e.trim()).toList();
      await storage.setStringList('user_tags', tagsList);
    }

    // Example 4: Add default values for new keys
    // Only set if key doesn't exist
    final hasLanguage = await storage.containsKey('language');
    if (!hasLanguage) {
      await storage.setString('language', 'en');
    }

    // Example 5: Clean up deprecated keys
    final deprecatedKeys = [
      'old_setting_1',
      'old_setting_2',
      'deprecated_key',
    ];

    for (final key in deprecatedKeys) {
      if (await storage.containsKey(key)) {
        await storage.remove(key);
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
        await storage.remove('user_data');
      }
    }
  }
}
