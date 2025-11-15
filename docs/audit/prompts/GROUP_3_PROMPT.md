# Group 3: Storage & Security - Self-Contained Implementation Prompt

**Last Updated:** November 15, 2025

## Context

I need to fix storage initialization issues and implement secure storage for sensitive data (tokens) in my Flutter Clean Architecture project. Currently, `StorageService` is initialized twice creating duplicate instances, and tokens are stored in plain text `SharedPreferences` instead of secure storage, which is a security risk.

## Current State

### Problems:
1. **StorageService initialized twice** - Created in `main.dart` and also via Riverpod provider
2. **Tokens in plain text** - Stored in `SharedPreferences` (insecure)
3. **flutter_secure_storage not used** - Dependency declared but not implemented
4. **Security risk** - Tokens can be extracted from device easily
5. **State inconsistency** - Two StorageService instances may have different state

### Current Files:
- `lib/main.dart` - Manually creates and initializes StorageService (line 22-23)
- `lib/core/di/providers.dart` - Provides StorageService via Riverpod (line 26-28)
- `lib/core/storage/storage_service.dart` - Uses SharedPreferences
- `lib/features/auth/data/datasources/auth_local_datasource.dart` - Stores tokens in SharedPreferences

## Requirements

### 1. Fix StorageService Initialization
**File:** `lib/main.dart`

- Remove manual `StorageService` creation and initialization
- Use Riverpod provider exclusively
- Create startup provider or initialization hook

### 2. Create SecureStorageService
**File:** `lib/core/storage/secure_storage_service.dart` (NEW)

- Implement `IStorageService` interface
- Use `flutter_secure_storage` for all operations
- Handle platform-specific secure storage
- Provide same API as `StorageService`

### 3. Update Storage Providers
**File:** `lib/core/di/providers.dart`

- Add startup initialization provider
- Initialize storage before app starts
- Ensure single instance throughout app lifecycle

### 4. Update AuthLocalDataSource
**File:** `lib/features/auth/data/datasources/auth_local_datasource.dart`

- Use `SecureStorageService` for tokens (`tokenKey`, `refreshTokenKey`)
- Keep `SharedPreferences` for user data (`userDataKey`)
- Update all token-related methods

### 5. Update Storage Service Architecture
**Decision:** Use both storage types appropriately
- `SecureStorageService` - For sensitive data (tokens, passwords)
- `StorageService` (SharedPreferences) - For non-sensitive data (user preferences, cache)

## Implementation Details

### SecureStorageService Structure:
```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_starter/core/storage/storage_service.dart';

class SecureStorageService implements IStorageService {
  SecureStorageService() : _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> getString(String key) async {
    return await _storage.read(key: key);
  }

  @override
  Future<bool> setString(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Implement all IStorageService methods
}
```

### Startup Provider:
```dart
// In providers.dart
final storageInitializationProvider = FutureProvider<void>((ref) async {
  final storageService = ref.read(storageServiceProvider);
  await storageService.init();
});
```

### Main.dart Update:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig.load();
  
  // REMOVE: Manual StorageService initialization
  
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}
```

### AuthLocalDataSource Update:
```dart
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  AuthLocalDataSourceImpl({
    required this.secureStorageService, // For tokens
    required this.storageService, // For user data
  });

  final SecureStorageService secureStorageService;
  final StorageService storageService;

  @override
  Future<void> cacheToken(String token) async {
    await secureStorageService.setString(AppConstants.tokenKey, token);
  }

  @override
  Future<void> cacheUser(UserModel user) async {
    // Use regular storage for user data
    final userJson = JsonHelper.encode(user.toJson());
    await storageService.setString(AppConstants.userDataKey, userJson);
  }
}
```

## Testing Requirements

1. **Test secure storage**
   - Test token storage and retrieval
   - Test secure storage on different platforms
   - Test error handling

2. **Test single instance**
   - Verify only one StorageService instance exists
   - Test initialization via Riverpod

3. **Test data separation**
   - Verify tokens in secure storage
   - Verify user data in SharedPreferences
   - Test clear operations

4. **Test initialization**
   - Test startup provider
   - Test initialization order
   - Test error handling during init

## Success Criteria

- ✅ Single StorageService instance via Riverpod
- ✅ Tokens stored in secure storage
- ✅ User data in SharedPreferences
- ✅ No security risks from plain text storage
- ✅ Proper initialization order
- ✅ All tests pass

## Files to Create

1. `lib/core/storage/secure_storage_service.dart` - Secure storage implementation

## Files to Modify

1. `lib/main.dart` - Remove manual initialization
2. `lib/core/di/providers.dart` - Add startup provider, secure storage provider
3. `lib/features/auth/data/datasources/auth_local_datasource.dart` - Use secure storage for tokens

## Dependencies

- `flutter_secure_storage` (already in pubspec.yaml)

---

## Common Mistakes to Avoid

### ❌ Don't store all data in secure storage
- Only sensitive data (tokens, passwords)
- Regular data in SharedPreferences for performance

### ❌ Don't create multiple instances
- Use Riverpod provider exclusively
- No manual instantiation

### ❌ Don't forget platform-specific options
- Configure Android and iOS options properly
- Handle platform differences

### ❌ Don't ignore initialization errors
- Handle secure storage initialization failures
- Provide fallback if needed

### ❌ Don't mix storage types incorrectly
- Clear separation: secure vs non-secure
- Document which data goes where

---

## Edge Cases to Handle

### 1. Secure Storage Unavailable
- Handle cases where secure storage fails to initialize
- Provide fallback or error handling
- Log errors appropriately

### 2. Platform-Specific Issues
- Handle Android/iOS differences
- Test on both platforms
- Handle permission issues

### 3. Migration from SharedPreferences
- Existing tokens in SharedPreferences
- Migrate to secure storage on first run
- Handle migration errors

### 4. Concurrent Access
- Ensure thread-safe operations
- Handle multiple simultaneous writes
- Prevent race conditions

### 5. Storage Full
- Handle storage quota exceeded
- Provide user-friendly error messages
- Clean up old data if needed

### 6. App Uninstall/Reinstall
- Secure storage persists on some platforms
- Handle stale data appropriately
- Clear on fresh install if needed

---

## Expected Deliverables

Provide responses in this order:

### 1. New SecureStorageService (Complete Code)

**1.1. `lib/core/storage/secure_storage_service.dart`**
- Complete implementation of IStorageService
- All methods implemented
- Platform-specific configuration
- Error handling

### 2. Updated Providers (Changes Only)

**2.1. `lib/core/di/providers.dart`**
- Show only the changes
- Secure storage provider
- Startup initialization provider
- Clear before/after context

### 3. Updated Main.dart (Changes Only)

**3.1. `lib/main.dart`**
- Show only the changes
- Removed manual initialization
- Updated initialization flow
- Clear before/after context

### 4. Updated AuthLocalDataSource (Changes Only)

**4.1. `lib/features/auth/data/datasources/auth_local_datasource.dart`**
- Show only the changes
- Secure storage for tokens
- Regular storage for user data
- Updated constructor and methods
- Clear before/after context

### 5. Test File Examples (At Least 2)

**5.1. `test/core/storage/secure_storage_service_test.dart`**
- Unit tests for secure storage
- Platform-specific tests
- Error handling tests

**5.2. `test/features/auth/data/datasources/auth_local_datasource_test.dart`**
- Test token storage in secure storage
- Test user data in SharedPreferences
- Test data separation

### 6. Migration Notes

**6.1. Breaking Changes**
- Storage initialization changes
- Data source constructor changes
- Provider updates

**6.2. Migration Steps**
- How to migrate existing tokens
- Update provider usage
- Update data source usage

---

## Implementation Checklist

Before submitting, verify:

- [ ] SecureStorageService implements IStorageService
- [ ] Platform-specific options configured
- [ ] Single StorageService instance via Riverpod
- [ ] Manual initialization removed from main.dart
- [ ] Tokens stored in secure storage
- [ ] User data in SharedPreferences
- [ ] Startup provider created
- [ ] AuthLocalDataSource updated
- [ ] All tests pass
- [ ] No security risks
- [ ] Error handling implemented
- [ ] Documentation updated

