# Storage APIs

Storage services for persisting data locally.

## Overview

The storage layer provides two services:
- `StorageService` - For non-sensitive data (uses SharedPreferences)
- `SecureStorageService` - For sensitive data (uses encrypted storage)

Both implement the `IStorageService` interface for consistent API.

---

## IStorageService

Abstract interface for storage operations.

**Location:** `lib/core/storage/storage_service.dart`

### Methods

```dart
/// Retrieves a string value from storage by [key]
Future<String?> getString(String key);

/// Stores a string [value] in storage with the given [key]
Future<bool> setString(String key, String value);

/// Retrieves an integer value from storage by [key]
Future<int?> getInt(String key);

/// Stores an integer [value] in storage with the given [key]
Future<bool> setInt(String key, int value);

/// Retrieves a boolean value from storage by [key]
Future<bool?> getBool(String key);

/// Stores a boolean [value] in storage with the given [key]
Future<bool> setBool(String key, {required bool value});

/// Retrieves a double value from storage by [key]
Future<double?> getDouble(String key);

/// Stores a double [value] in storage with the given [key]
Future<bool> setDouble(String key, double value);

/// Retrieves a list of strings from storage by [key]
Future<List<String>?> getStringList(String key);

/// Stores a list of strings [value] in storage with the given [key]
Future<bool> setStringList(String key, List<String> value);

/// Removes a value from storage by [key]
Future<bool> remove(String key);

/// Clears all values from storage
Future<bool> clear();

/// Checks if storage contains a value for the given [key]
Future<bool> containsKey(String key);
```

---

## StorageService

Implementation of storage service using SharedPreferences for non-sensitive data.

**Location:** `lib/core/storage/storage_service.dart`

### Constructor

```dart
/// Creates a [StorageService] instance
StorageService();
```

### Features

- Uses SharedPreferences for persistence
- Lazy initialization of SharedPreferences instance
- Thread-safe operations
- Suitable for: user preferences, cached data, app settings

### Initialization

```dart
final storage = StorageService();
await storage.init(); // Optional explicit initialization
```

### Usage Examples

```dart
final storage = ref.read(storageServiceProvider);

// Store values
await storage.setString('username', 'john');
await storage.setInt('user_id', 123);
await storage.setBool('is_dark_mode', value: true);
await storage.setDouble('rating', 4.5);
await storage.setStringList('tags', ['flutter', 'dart']);

// Retrieve values
final username = await storage.getString('username');
final userId = await storage.getInt('user_id');
final isDarkMode = await storage.getBool('is_dark_mode');
final rating = await storage.getDouble('rating');
final tags = await storage.getStringList('tags');

// Check if key exists
final exists = await storage.containsKey('username');

// Remove value
await storage.remove('username');

// Clear all
await storage.clear();
```

---

## SecureStorageService

Secure storage service implementation using flutter_secure_storage for sensitive data.

**Location:** `lib/core/storage/secure_storage_service.dart`

### Constructor

```dart
/// Creates a [SecureStorageService] instance with platform-specific options
/// 
/// Platform-specific:
/// - Android: Uses EncryptedSharedPreferences
/// - iOS: Uses Keychain with first unlock accessibility
SecureStorageService();
```

### Features

- Encrypted storage on Android (EncryptedSharedPreferences)
- Keychain storage on iOS
- Implements `IStorageService` interface
- Safe error handling (returns null/false on errors)
- Suitable for: authentication tokens, passwords, API keys, sensitive information

### Platform-Specific Behavior

**Android:**
- Uses EncryptedSharedPreferences
- Data is encrypted at rest

**iOS:**
- Uses Keychain
- Accessibility: `first_unlock_this_device`
- Data is encrypted and protected by iOS security

### Usage Examples

```dart
final secureStorage = ref.read(secureStorageServiceProvider);

// Store sensitive data
await secureStorage.setString('token', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...');
await secureStorage.setString('refresh_token', 'refresh_token_here');
await secureStorage.setString('api_key', 'secret-api-key');

// Retrieve sensitive data
final token = await secureStorage.getString('token');
final refreshToken = await secureStorage.getString('refresh_token');
final apiKey = await secureStorage.getString('api_key');

// Remove sensitive data
await secureStorage.remove('token');

// Clear all sensitive data
await secureStorage.clear();
```

### Error Handling

SecureStorageService handles errors gracefully:
- Returns `null` for get operations on error
- Returns `false` for set/remove operations on error
- Never throws exceptions

```dart
final token = await secureStorage.getString('token');
if (token == null) {
  // Token doesn't exist or error occurred
  // Handle accordingly
}
```

---

## When to Use Which Service

### Use StorageService for:
- User preferences (theme, language)
- App settings
- Cached data (non-sensitive)
- Feature flags
- Any non-sensitive data

### Use SecureStorageService for:
- Authentication tokens (access token, refresh token)
- Passwords
- API keys
- Credit card information
- Any sensitive or personal data

---

## Best Practices

### 1. Use Secure Storage for Tokens

```dart
// ✅ Good
await secureStorage.setString('token', token);

// ❌ Bad
await storage.setString('token', token);
```

### 2. Initialize Storage Before Use

```dart
// In main.dart
await container.read(storageInitializationProvider.future);
```

### 3. Handle Null Values

```dart
final value = await storage.getString('key');
if (value != null) {
  // Use value
} else {
  // Handle missing value
}
```

### 4. Use Constants for Keys

```dart
class StorageKeys {
  static const String token = 'auth_token';
  static const String refreshToken = 'refresh_token';
  static const String userId = 'user_id';
}

await secureStorage.setString(StorageKeys.token, token);
```

### 5. Clear Data on Logout

```dart
Future<void> logout() async {
  // Clear sensitive data
  await secureStorage.remove(StorageKeys.token);
  await secureStorage.remove(StorageKeys.refreshToken);
  
  // Clear non-sensitive data if needed
  await storage.remove(StorageKeys.userId);
}
```

---

## Related APIs

- [Network](network.md) - Uses secure storage for tokens
- [Features - Auth Providers](../features/auth/providers.md) - Uses storage services
- [Configuration](../../README.md#configuration) - AppConfig for configuration

