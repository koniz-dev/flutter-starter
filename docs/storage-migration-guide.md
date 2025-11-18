# Storage Migration Guide

This guide explains how to use and extend the storage migration system in your Flutter app.

## Overview

The storage migration system allows you to safely update your storage schema when your app evolves. It ensures that:

- Data is migrated gracefully without loss
- Migrations run automatically on app startup
- Both regular and secure storage are supported
- All migration activities are logged
- Errors are handled gracefully

## Architecture

The migration system consists of:

1. **StorageVersion** - Defines version constants and keys
2. **StorageMigration** - Abstract base class for migrations
3. **MigrationExecutor** - Executes migrations in sequence
4. **MigrationRegistry** - Central registry of all migrations
5. **StorageMigrationService** - Coordinates migrations for both storage types

## How It Works

1. On app startup, `storageInitializationProvider` runs
2. It creates a `StorageMigrationService` instance
3. The service checks the current storage version
4. If migrations are needed, they execute in sequence
5. Version is updated after each successful migration
6. All activities are logged

## Creating a Migration

### Step 1: Create Migration Class

Create a new file in `lib/core/storage/migration/migrations/`:

```dart
import 'package:flutter_starter/core/storage/migration/storage_migration.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';

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
    // Example: Rename a key
    final oldValue = await storage.getString('old_key');
    if (oldValue != null) {
      await storage.setString('new_key', oldValue);
      await storage.remove('old_key');
    }
  }
}
```

### Step 2: Register Migration

Add your migration to `MigrationRegistry`:

```dart
// lib/core/storage/migration/migration_registry.dart
static List<StorageMigration> get migrations => [
  MigrationV1ToV2(),
  MigrationV2ToV3(), // Add your new migration
  // ... more migrations
];
```

### Step 3: Update Version

Update `StorageVersion.current`:

```dart
// lib/core/storage/storage_version.dart
class StorageVersion {
  static const int current = 3; // Update to new version
  // ...
}
```

## Migration Patterns

### Renaming Keys

```dart
final oldValue = await storage.getString('old_key');
if (oldValue != null) {
  await storage.setString('new_key', oldValue);
  await storage.remove('old_key');
}
```

### Transforming Data

```dart
final oldTheme = await storage.getString('theme');
if (oldTheme != null) {
  String newTheme;
  switch (oldTheme.toLowerCase()) {
    case 'dark':
      newTheme = 'dark';
      break;
    case 'light':
      newTheme = 'light';
      break;
    default:
      newTheme = 'system';
  }
  await storage.setString('theme_mode', newTheme);
  await storage.remove('theme');
}
```

### Migrating Lists

```dart
final oldTags = await storage.getString('user_tags');
if (oldTags != null && oldTags.isNotEmpty) {
  final tagsList = oldTags.split(',').map((e) => e.trim()).toList();
  await storage.setStringList('user_tags', tagsList);
}
```

### Adding Default Values

```dart
final hasLanguage = await storage.containsKey('language');
if (!hasLanguage) {
  await storage.setString('language', 'en');
}
```

### Cleaning Up Deprecated Keys

```dart
final deprecatedKeys = ['old_setting_1', 'old_setting_2'];
for (final key in deprecatedKeys) {
  if (await storage.containsKey(key)) {
    await storage.remove(key);
  }
}
```

## Best Practices

### 1. Idempotent Migrations

Migrations should be idempotent - running them multiple times should produce the same result:

```dart
// Good: Checks if key exists before migrating
final oldValue = await storage.getString('old_key');
if (oldValue != null) {
  await storage.setString('new_key', oldValue);
  await storage.remove('old_key');
}

// Bad: Doesn't check, might fail on second run
await storage.setString('new_key', await storage.getString('old_key'));
await storage.remove('old_key');
```

### 2. Handle Missing Data

Always check for null values:

```dart
final value = await storage.getString('key');
if (value != null) {
  // Process value
}
```

### 3. Error Handling

The migration system handles errors automatically, but you can add custom validation:

```dart
@override
Future<bool> canMigrate(IStorageService storage) async {
  // Custom validation logic
  final requiredKey = await storage.getString('required_key');
  if (requiredKey == null) {
    return false; // Cannot migrate without required data
  }
  return await super.canMigrate(storage);
}
```

### 4. Test Your Migrations

Always write tests for your migrations:

```dart
test('migration renames key correctly', () async {
  await storage.setString('old_key', 'value');
  final migration = MigrationV2ToV3();
  await migration.execute(storage);
  
  expect(await storage.getString('new_key'), equals('value'));
  expect(await storage.containsKey('old_key'), isFalse);
});
```

## Storage-Specific Migrations

If you need different migrations for regular vs secure storage, override the registry methods:

```dart
// lib/core/storage/migration/migration_registry.dart
static List<StorageMigration> get regularStorageMigrations => [
  MigrationV1ToV2(),
  MigrationV2ToV3(),
];

static List<StorageMigration> get secureStorageMigrations => [
  MigrationV1ToV2(),
  SecureStorageMigrationV2ToV3(), // Different migration for secure storage
];
```

## Manual Migration Execution

If you need to run migrations manually (e.g., for testing):

```dart
final migrationService = StorageMigrationService(
  storageService: storageService,
  secureStorageService: secureStorageService,
  loggingService: loggingService,
);

// Migrate both storage types
await migrationService.migrateAll();

// Or migrate individually
await migrationService.migrateRegular();
await migrationService.migrateSecure();
```

## Troubleshooting

### Migration Not Running

1. Check that migration is registered in `MigrationRegistry`
2. Verify `StorageVersion.current` is updated
3. Check logs for migration errors
4. Ensure `storageInitializationProvider` is awaited in main

### Migration Fails

1. Check logs for detailed error messages
2. Verify migration logic handles edge cases
3. Test migration with sample data
4. Ensure migration is idempotent

### Version Mismatch

If you see version mismatch warnings:

1. Check that all migrations update version correctly
2. Verify migration chain is complete (no gaps)
3. Check for corrupted version data

## Testing

The migration system includes comprehensive tests:

- `test/core/storage/migration/storage_migration_test.dart` - Tests migration base class
- `test/core/storage/migration/migration_executor_test.dart` - Tests executor
- `test/core/storage/migration/storage_migration_service_test.dart` - Tests service

Run tests with:

```bash
flutter test test/core/storage/migration/
```

## Example: Complete Migration

Here's a complete example of migrating from v1 to v2:

```dart
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
    final oldUserName = await storage.getString('user_name');
    if (oldUserName != null) {
      await storage.setString('username', oldUserName);
      await storage.remove('user_name');
    }

    // 2. Transform data
    final oldTheme = await storage.getString('theme');
    if (oldTheme != null) {
      final newTheme = _transformTheme(oldTheme);
      await storage.setString('theme_mode', newTheme);
      await storage.remove('theme');
    }

    // 3. Add defaults
    if (!await storage.containsKey('language')) {
      await storage.setString('language', 'en');
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
```

## Summary

The storage migration system provides a robust, maintainable way to handle schema changes. By following the patterns and best practices outlined in this guide, you can ensure smooth transitions for your users as your app evolves.

