# Storage APIs

Storage services for persisting data locally.

## Overview

The storage layer provides two services:
- `StorageService` - For non-sensitive data (uses SharedPreferences)
- `SecureStorageService` - For sensitive data (uses encrypted storage)
- `IKeyValueStore` - Contract for non-sensitive key-value persistence
- `ITokenStore` - Contract for access/refresh token lifecycle
- `ILocalDatabase` - Interface for advanced relational/document storage (Template)

Both implement the `IStorageService` interface for consistent API.

The decoupled runtime path now uses `IKeyValueStore` and `ITokenStore` in
auth/network boundaries to avoid direct concrete coupling.

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
/// - Android: the plugin's default cipher storage (no AndroidOptions passed)
/// - iOS: Uses Keychain with first unlock accessibility
SecureStorageService();
```

### Features

- Encrypted storage on Android (AES-GCM, Keystore-backed key)
- Keychain storage on iOS
- Implements `IStorageService` interface
- Safe error handling (returns null/false on errors)
- Suitable for: authentication tokens, passwords, API keys, sensitive information

### Platform-Specific Behavior

**Android:**
- Uses `flutter_secure_storage`'s default Android options; `SecureStorageService`
  passes no `AndroidOptions`
- Values are encrypted with AES-GCM; the AES key is wrapped with RSA-OAEP by a
  key held in the Android Keystore
- `resetOnError` is `true` (the plugin default): if the key cannot be
  recovered - for example after a backup is restored to another device - the
  plugin deletes every stored value, and the user has to sign in again

**iOS:**
- Uses Keychain
- Accessibility: `first_unlock_this_device`
- Data is encrypted and protected by iOS security

**Web:**
- `SecureStorageService` passes no web options, so `flutter_secure_storage_web`
  keeps every value - the access and refresh tokens included - in the page's
  `window.localStorage`
- Values are AES-GCM encrypted with WebCrypto, but with no wrap key the plugin
  stores the AES key itself, raw, in the same `localStorage`. The encryption
  therefore protects nothing from code running on the origin: **any script that
  runs on the page (an XSS, a compromised dependency) can read both tokens**
- There is no web equivalent of the Keystore or Keychain to fix this in the
  client. What an adopter shipping web should do instead:
  - send a strict Content-Security-Policy as a response header, so injected
    script does not run in the first place (see the security implementation
    guide, and mind Flutter's own CanvasKit and font origins)
  - keep access tokens short-lived
  - have the server keep the refresh token in an `httpOnly`, `Secure`,
    `SameSite` cookie, so it never reaches `localStorage` at all
- A `wrapKey` web option only moves the key into the JavaScript bundle, which
  the same script can read; it is not a fix

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

## Local Database (Advanced Storage)

The project provides an interface `ILocalDatabase` for advanced offline storage (Listings, Searching, Schema-based) which complements the simple Key-Value `IStorageService`.

**Location:** `lib/core/storage/local_database.dart`

### Interface

The template conforms to `ILocalDatabase`:

```dart
abstract class ILocalDatabase {
  /// Initialize or open the database connection
  Future<void> init();

  /// Save a single model/document
  Future<void> save<T>(T object);

  /// Save a list of models/documents
  Future<void> saveAll<T>(List<T> objects);

  /// Retrieve all objects of type T
  Future<List<T>> getAll<T>();

  /// Retreive a single object by its primary key
  Future<T?> getById<T>(int id);

  /// Delete an object by its primary key
  Future<bool> delete<T>(int id);

  /// Clears the entire table/collection for type T
  Future<void> clear<T>();

  /// Close connection
  Future<void> close();
}
```

### Isar Implementation Template

A ready-to-uncomment implementation on **Isar** (high-performance NoSQL for
Flutter), through the community-maintained Isar 3 packages.

**Location:** `lib/core/storage/isar_database_template.dart`

#### Setup

1. Run: `flutter pub add isar_community isar_community_flutter_libs`
2. Run: `flutter pub add --dev isar_community_generator`
3. Uncomment the imports and code in the template file, define your
   collections (a class annotated `@collection`, in a file with
   `part '<file>.g.dart';`), list their schemas in `Isar.open`, and run
   `dart run build_runner build --delete-conflicting-outputs`.

Use these packages rather than the original `isar` / `isar_generator` 3.x:
their generator needs `source_gen` 1.x, while this project's `freezed` 4
needs `source_gen` 3 or later, so `flutter pub add --dev isar_generator`
fails version solving here.

The default starter does not bind `ILocalDatabase` in DI, so this remains fully optional.


---

## Best Practices

### 1. Use Secure Storage for Tokens

```dart
// Good
await secureStorage.setString('token', token);

// Bad
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
- [Configuration](../../guides/configuration.md) - AppConfig for configuration


