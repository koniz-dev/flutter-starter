# Group 2: Configuration Cleanup - Self-Contained Implementation Prompt

**Last Updated:** November 15, 2025

## Context

I need to clean up duplicate configuration sources in my Flutter Clean Architecture project. Currently, BASE_URL and timeout values are defined in multiple places with different behaviors, causing confusion and inconsistent behavior. This creates a single source of truth problem.

## Current State

### Problems:
1. **BASE_URL duplication** - Defined in both `ApiEndpoints` (compile-time) and `AppConfig` (runtime)
2. **Timeout duplication** - Defined in `AppConstants`, `AppConfig`, and hardcoded in `ApiClient`
3. **Unused constants** - `AppConstants` has values that are never used
4. **Configuration ignored** - `ApiClient` hardcodes timeout values instead of using `AppConfig`
5. **App version duplication** - Hardcoded in `AppConstants` but also in `AppConfig` from environment

### Current Files:
- `lib/core/constants/api_endpoints.dart` - Has `baseUrl` using `String.fromEnvironment()` (compile-time only)
- `lib/core/constants/app_constants.dart` - Has hardcoded timeouts and app version
- `lib/core/config/app_config.dart` - Has runtime configuration with .env support
- `lib/core/network/api_client.dart` - Hardcodes timeout values (30s)

## Requirements

### 1. Remove Duplicate BASE_URL
**File:** `lib/core/constants/api_endpoints.dart`

- Remove `baseUrl` constant (lines 6-12)
- Keep only endpoint path constants
- `ApiEndpoints` should only contain endpoint paths, not configuration

### 2. Remove Unused Timeout Constants
**File:** `lib/core/constants/app_constants.dart`

- Remove `connectionTimeout` constant (line 12)
- Remove `receiveTimeout` constant (line 15)
- Keep only constants that are actually used (storage keys, pagination, etc.)

### 3. Remove App Version Duplication
**File:** `lib/core/constants/app_constants.dart`

- Remove `appVersion` constant (line 9)
- Use only `AppConfig.appVersion` which reads from environment

### 4. Update ApiClient to Use Config Timeouts
**File:** `lib/core/network/api_client.dart`

- Replace hardcoded `Duration(seconds: 30)` with `AppConfig.apiConnectTimeout`
- Replace hardcoded `Duration(seconds: 30)` with `AppConfig.apiReceiveTimeout`
- Use `Duration(seconds: AppConfig.apiConnectTimeout)` for connectTimeout
- Use `Duration(seconds: AppConfig.apiReceiveTimeout)` for receiveTimeout

### 5. Verify AppConfig Usage
**File:** `lib/core/config/app_config.dart`

- Ensure all config values are actually used
- Verify timeout values are properly exposed
- Check that BASE_URL is the single source of truth

## Implementation Details

### ApiEndpoints Cleanup:
```dart
class ApiEndpoints {
  ApiEndpoints._();

  // REMOVE: static const String baseUrl = ...;
  
  // KEEP: Only endpoint paths
  static const String apiVersion = '/v1';
  static const String login = '/auth/login';
  // ... other endpoints
}
```

### AppConstants Cleanup:
```dart
class AppConstants {
  AppConstants._();

  // REMOVE: static const String appVersion = '1.0.0';
  // REMOVE: static const Duration connectionTimeout = ...;
  // REMOVE: static const Duration receiveTimeout = ...;
  
  // KEEP: Only used constants
  static const String appName = 'Flutter Starter';
  static const String tokenKey = 'auth_token';
  // ... other used constants
}
```

### ApiClient Update:
```dart
static Dio _createDio(StorageService storageService) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl + ApiEndpoints.apiVersion,
      connectTimeout: Duration(seconds: AppConfig.apiConnectTimeout),
      receiveTimeout: Duration(seconds: AppConfig.apiReceiveTimeout),
      // ... rest of config
    ),
  );
  // ...
}
```

## Testing Requirements

1. **Verify single source of truth**
   - Test that BASE_URL comes only from `AppConfig`
   - Test that timeouts come only from `AppConfig`
   - Verify no hardcoded values remain

2. **Test configuration loading**
   - Test .env file loading
   - Test --dart-define fallback
   - Test default values

3. **Test ApiClient configuration**
   - Verify ApiClient uses AppConfig values
   - Test timeout values are applied correctly
   - Test BASE_URL is constructed correctly

## Success Criteria

- ✅ Single source of truth for BASE_URL (`AppConfig`)
- ✅ Single source of truth for timeouts (`AppConfig`)
- ✅ No unused constants in `AppConstants`
- ✅ `ApiClient` uses config values, not hardcoded
- ✅ No duplicate configuration definitions
- ✅ All tests pass

## Files to Modify

1. `lib/core/constants/api_endpoints.dart` - Remove baseUrl
2. `lib/core/constants/app_constants.dart` - Remove unused constants
3. `lib/core/network/api_client.dart` - Use AppConfig timeouts
4. `lib/core/config/app_config.dart` - Verify all values used

## Dependencies

- None (standalone cleanup)

---

## Common Mistakes to Avoid

### ❌ Don't remove constants that are actually used
- Check all usages before removing
- Keep storage keys, pagination constants, etc.

### ❌ Don't break existing functionality
- Ensure ApiClient still works after changes
- Verify BASE_URL construction is correct

### ❌ Don't create new duplication
- Don't add new config sources
- Use AppConfig for all runtime configuration

### ❌ Don't forget to update imports
- If constants are removed, update any imports
- Check for unused imports

---

## Edge Cases to Handle

### 1. Missing Environment Variables
- AppConfig should provide sensible defaults
- Test fallback chain: .env → dart-define → defaults

### 2. Invalid Timeout Values
- Handle negative or zero timeout values
- Provide minimum timeout values if needed

### 3. BASE_URL Construction
- Ensure BASE_URL + apiVersion concatenation is correct
- Handle trailing slashes properly

### 4. Configuration at Startup
- Verify AppConfig values are available when ApiClient is created
- Handle initialization order

---

## Expected Deliverables

Provide responses in this order:

### 1. Updated ApiEndpoints (Complete Code)

**1.1. `lib/core/constants/api_endpoints.dart`**
- Complete file with baseUrl removed
- Only endpoint path constants
- Clear comments

### 2. Updated AppConstants (Complete Code)

**2.1. `lib/core/constants/app_constants.dart`**
- Complete file with unused constants removed
- Only constants that are actually used
- Clear organization

### 3. Updated ApiClient (Changes Only)

**3.1. `lib/core/network/api_client.dart`**
- Show only the changes
- Timeout configuration updates
- BASE_URL usage verification
- Clear before/after context

### 4. Verification Notes

**4.1. Configuration Verification**
- List all configuration sources
- Verify single source of truth
- Document any remaining constants and their purpose

### 5. Test File Examples (Optional)

**5.1. `test/core/config/app_config_test.dart`**
- Test configuration loading
- Test fallback chain
- Test default values

---

## Implementation Checklist

Before submitting, verify:

- [ ] BASE_URL removed from ApiEndpoints
- [ ] Unused timeout constants removed
- [ ] App version removed from AppConstants
- [ ] ApiClient uses AppConfig timeouts
- [ ] No hardcoded timeout values remain
- [ ] Single source of truth for all config
- [ ] All existing functionality works
- [ ] No unused imports
- [ ] Configuration properly documented

