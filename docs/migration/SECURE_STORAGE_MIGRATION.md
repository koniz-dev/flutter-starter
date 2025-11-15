# Secure Storage Migration Guide

## Overview

This document describes the migration from plain text token storage to secure encrypted storage, and the fix for duplicate StorageService initialization.

## Breaking Changes

### 1. AuthLocalDataSource Constructor Change

**Before:**
```dart
AuthLocalDataSourceImpl(StorageService storageService)
```

**After:**
```dart
AuthLocalDataSourceImpl({
  required StorageService storageService,
  required SecureStorageService secureStorageService,
})
```

The constructor now requires both `StorageService` and `SecureStorageService`.

### 2. ApiClient Constructor Change

**Before:**
```dart
ApiClient({required StorageService storageService})
```

**After:**
```dart
ApiClient({
  required StorageService storageService,
  required SecureStorageService secureStorageService,
})
```

The constructor now requires both storage services.

### 3. AuthInterceptor Constructor Change

**Before:**
```dart
AuthInterceptor(StorageService storageService)
```

**After:**
```dart
AuthInterceptor(SecureStorageService secureStorageService)
```

The interceptor now uses `SecureStorageService` instead of `StorageService`.

### 4. Storage Initialization Change

**Before:**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig.load();
  
  // Manual initialization
  final storageService = StorageService();
  await storageService.init();
  
  runApp(ProviderScope(child: MyApp()));
}
```

**After:**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig.load();
  
  // Initialize via provider
  final container = ProviderContainer();
  await container.read(storageInitializationProvider.future);
  
  runApp(UncontrolledProviderScope(container: container, child: MyApp()));
}
```

## Migration Steps

### Step 1: Update Provider Usage

**No changes needed** - Providers are automatically updated. The `authLocalDataSourceProvider` and `apiClientProvider` now use both storage services.

### Step 2: Update Manual Instantiations

If you're manually creating `AuthLocalDataSource` or `ApiClient`:

**Before:**
```dart
final dataSource = AuthLocalDataSourceImpl(storageService);
final apiClient = ApiClient(storageService: storageService);
```

**After:**
```dart
final dataSource = AuthLocalDataSourceImpl(
  storageService: storageService,
  secureStorageService: secureStorageService,
);
final apiClient = ApiClient(
  storageService: storageService,
  secureStorageService: secureStorageService,
);
```

### Step 3: Token Migration (Optional)

If you have existing tokens in `SharedPreferences`, you may want to migrate them to secure storage:

```dart
// Migration helper (run once on app update)
Future<void> migrateTokensToSecureStorage() async {
  final storageService = ref.read(storageServiceProvider);
  final secureStorageService = ref.read(secureStorageServiceProvider);
  
  // Check if tokens exist in old storage
  final oldToken = await storageService.getString(AppConstants.tokenKey);
  final oldRefreshToken = await storageService.getString(AppConstants.refreshTokenKey);
  
  if (oldToken != null) {
    // Migrate to secure storage
    await secureStorageService.setString(AppConstants.tokenKey, oldToken);
    await storageService.remove(AppConstants.tokenKey);
  }
  
  if (oldRefreshToken != null) {
    await secureStorageService.setString(AppConstants.refreshTokenKey, oldRefreshToken);
    await storageService.remove(AppConstants.refreshTokenKey);
  }
}
```

## New Features

### 1. SecureStorageService

A new service for encrypted storage of sensitive data:

```dart
final secureStorageService = ref.read(secureStorageServiceProvider);

// Store sensitive data
await secureStorageService.setString('api_key', 'secret_key');

// Retrieve sensitive data
final apiKey = await secureStorageService.getString('api_key');
```

**Platform-specific:**
- **Android:** Uses EncryptedSharedPreferences
- **iOS:** Uses Keychain with first unlock accessibility

### 2. Data Separation

**SecureStorageService** - For sensitive data:
- Authentication tokens
- API keys
- Passwords
- Other sensitive information

**StorageService** - For non-sensitive data:
- User preferences
- Cached data
- Theme settings
- Language preferences

### 3. Single Instance via Riverpod

Storage services are now managed exclusively through Riverpod providers, ensuring:
- Single instance throughout app lifecycle
- Proper initialization order
- No duplicate instances

## Architecture Changes

### Storage Flow

```
┌─────────────────────────────────────┐
│         Riverpod Providers          │
├─────────────────────────────────────┤
│  storageServiceProvider             │
│  secureStorageServiceProvider       │
│  storageInitializationProvider      │
└─────────────────────────────────────┘
           │              │
           ▼              ▼
    ┌──────────┐    ┌──────────────┐
    │ Storage  │    │   Secure     │
    │ Service  │    │   Storage    │
    │(Shared   │    │   Service    │
    │ Prefs)   │    │ (Encrypted)  │
    └──────────┘    └──────────────┘
           │              │
           ▼              ▼
    ┌──────────┐    ┌──────────────┐
    │  User    │    │   Tokens     │
    │  Data    │    │   (Secure)   │
    └──────────┘    └──────────────┘
```

### Provider Dependencies

```
storageServiceProvider
    ↓
authLocalDataSourceProvider ──┐
                              ├──→ Uses both
secureStorageServiceProvider  │
    ↓                          │
apiClientProvider ─────────────┘
    ↓
authInterceptor (uses secureStorageService)
```

## Testing

### Unit Tests

Comprehensive tests are available:
- `test/core/storage/secure_storage_service_test.dart` - Secure storage operations
- `test/features/auth/data/datasources/auth_local_datasource_test.dart` - Data source with secure storage

### Running Tests

```bash
flutter test test/core/storage/
flutter test test/features/auth/data/datasources/
```

## Security Improvements

### Before
- ❌ Tokens stored in plain text SharedPreferences
- ❌ Tokens accessible via device file system
- ❌ No encryption for sensitive data

### After
- ✅ Tokens stored in encrypted storage
- ✅ Android: EncryptedSharedPreferences
- ✅ iOS: Keychain with proper accessibility
- ✅ Sensitive data protected from unauthorized access

## Common Patterns

### Storing Sensitive Data

```dart
final secureStorage = ref.read(secureStorageServiceProvider);

// Store API key
await secureStorage.setString('api_key', secretKey);

// Store password (if needed)
await secureStorage.setString('password', userPassword);
```

### Storing Non-Sensitive Data

```dart
final storage = ref.read(storageServiceProvider);

// Store user preferences
await storage.setString('theme', 'dark');
await storage.setBool('notifications_enabled', true);
```

### Accessing Tokens

```dart
// Tokens are automatically retrieved by AuthInterceptor
// No manual access needed in most cases

// If manual access is needed:
final secureStorage = ref.read(secureStorageServiceProvider);
final token = await secureStorage.getString(AppConstants.tokenKey);
```

## Troubleshooting

### Issue: Secure Storage Not Available

**Symptom:** `setString` returns `false` or `getString` returns `null`

**Solutions:**
1. Check platform-specific permissions
2. Verify flutter_secure_storage is properly configured
3. Check device storage availability
4. Review error logs for specific platform errors

### Issue: Tokens Not Found After Migration

**Symptom:** App can't find tokens after update

**Solution:**
- Run token migration helper (see Step 3 above)
- Check if tokens exist in old SharedPreferences
- Verify secure storage is working

### Issue: Multiple StorageService Instances

**Symptom:** Data inconsistency, tokens not accessible

**Solution:**
- Ensure using Riverpod providers exclusively
- Remove any manual `StorageService()` instantiation
- Use `ref.read(storageServiceProvider)` instead

## Notes

- Secure storage may have platform-specific limitations
- Some platforms may require device unlock for first access
- Secure storage persists across app updates (unlike SharedPreferences on some platforms)
- Performance: Secure storage is slightly slower than SharedPreferences, but acceptable for sensitive data

## Backward Compatibility

- ✅ Existing user data in SharedPreferences remains accessible
- ✅ No data loss during migration
- ✅ Tokens can be migrated from old storage if needed
- ⚠️ Breaking changes in constructors require code updates

---

**Status:** ✅ **COMPLETE** - Secure storage implemented, duplicate initialization fixed, single source of truth established.

