# Token Refresh & Auth Interceptor Migration Guide

**Last Updated:** December 2024

## Overview

This migration guide covers the implementation of automatic token refresh in the `AuthInterceptor`. The interceptor now automatically handles 401 Unauthorized responses by refreshing the access token and retrying the original request.

## Breaking Changes

### 1. AuthInterceptor Constructor

**Before:**
```dart
AuthInterceptor(SecureStorageService secureStorageService)
```

**After:**
```dart
AuthInterceptor({
  required SecureStorageService secureStorageService,
  required AuthRepository authRepository,
})
```

**Impact:** Any code that directly instantiates `AuthInterceptor` must be updated to provide both `secureStorageService` and `authRepository`.

### 2. ApiClient Constructor

**Before:**
```dart
ApiClient({
  required StorageService storageService,
  required SecureStorageService secureStorageService,
})
```

**After:**
```dart
ApiClient({
  required StorageService storageService,
  required SecureStorageService secureStorageService,
  required AuthInterceptor authInterceptor,
})
```

**Impact:** `ApiClient` now requires an `AuthInterceptor` instance. This is typically handled via dependency injection.

### 3. Provider Updates

**New Provider:**
- `authInterceptorProvider` - Provides `AuthInterceptor` instance

**Updated Providers:**
- `apiClientProvider` - Now depends on `authInterceptorProvider`
- `authRemoteDataSourceProvider` - Uses `ref.read` to break circular dependency
- `authRepositoryProvider` - Uses `ref.read` to break circular dependency

**Impact:** Provider initialization order may need adjustment. The providers use `ref.read` to break circular dependencies.

## Migration Steps

### Step 1: Update Provider Usage

If you're manually creating `ApiClient` or `AuthInterceptor`, update to use providers:

**Before:**
```dart
final storageService = StorageService();
final secureStorageService = SecureStorageService();
final apiClient = ApiClient(
  storageService: storageService,
  secureStorageService: secureStorageService,
);
```

**After:**
```dart
final container = ProviderContainer();
final apiClient = container.read(apiClientProvider);
```

### Step 2: Verify Token Refresh Flow

1. **Test 401 Response Handling:**
   - Make an API request with an expired token
   - Verify that the token is automatically refreshed
   - Verify that the original request is retried

2. **Test Refresh Failure:**
   - Simulate a refresh token expiry
   - Verify that the user is logged out
   - Verify that tokens are cleared

3. **Test Concurrent Requests:**
   - Make multiple requests simultaneously that result in 401
   - Verify that only one refresh occurs
   - Verify that all requests are retried after refresh

### Step 3: Update Error Handling

The interceptor now handles 401 errors automatically. You may need to update error handling in your UI:

**Before:**
```dart
try {
  final response = await apiClient.get('/api/user/profile');
} on AuthException catch (e) {
  if (e.code == '401') {
    // Manual token refresh logic
  }
}
```

**After:**
```dart
try {
  final response = await apiClient.get('/api/user/profile');
  // Token refresh handled automatically
} on AuthException catch (e) {
  // Only handle non-401 auth errors
  // 401 errors are automatically handled by interceptor
}
```

### Step 4: Test Excluded Endpoints

The following endpoints are excluded from automatic token refresh:
- `/auth/login`
- `/auth/register`
- `/auth/refresh`
- `/auth/logout`

These endpoints will not trigger token refresh on 401 errors, which is the expected behavior.

## New Features

### 1. Automatic Token Refresh

When a 401 Unauthorized response is received:
1. The interceptor checks if the endpoint should be excluded
2. If not excluded, it attempts to refresh the token
3. On success, it retries the original request with the new token
4. On failure, it logs out the user and clears tokens

### 2. Infinite Retry Prevention

The interceptor uses an `X-Retry-Count` header to prevent infinite retry loops:
- First 401: Attempts token refresh
- Second 401 (with `X-Retry-Count: 1`): Logs out user

### 3. Concurrent Request Handling

When multiple requests receive 401 simultaneously:
- Only one token refresh operation occurs
- Other requests are queued
- All requests are retried after successful refresh

### 4. Endpoint Exclusion

Auth-related endpoints are excluded from token refresh to prevent infinite loops:
- Login, register, refresh, and logout endpoints bypass refresh logic

## Testing

### Unit Tests

Comprehensive unit tests are available:
- `test/core/network/interceptors/auth_interceptor_test.dart`

**Test Coverage:**
- ✅ Token injection in requests
- ✅ 401 error handling
- ✅ Token refresh flow
- ✅ Refresh failure handling
- ✅ Infinite retry prevention
- ✅ Concurrent request handling
- ✅ Endpoint exclusion
- ✅ Non-401 error passthrough

### Running Tests

```bash
flutter test test/core/network/interceptors/auth_interceptor_test.dart
```

### Integration Tests

For end-to-end testing, create integration tests that:
1. Make API requests with expired tokens
2. Verify automatic refresh and retry
3. Test logout flow on refresh failure

## Troubleshooting

### Issue: Token Refresh Not Triggering

**Symptoms:**
- 401 errors not triggering refresh
- Manual re-login required

**Solutions:**
1. Verify `AuthInterceptor` is added to Dio interceptors
2. Check that `authRepository.refreshToken()` is properly implemented
3. Verify refresh token exists in secure storage
4. Check endpoint exclusion list

### Issue: Infinite Retry Loop

**Symptoms:**
- Requests continuously retrying
- App becomes unresponsive

**Solutions:**
1. Verify `X-Retry-Count` header is being set
2. Check that retry count check is working
3. Ensure refresh token endpoint is excluded

### Issue: Concurrent Requests Not Queued

**Symptoms:**
- Multiple refresh operations occurring
- Race conditions

**Solutions:**
1. Verify `_isRefreshing` flag is properly managed
2. Check that request queuing is working
3. Ensure pending requests are retried after refresh

### Issue: User Not Logged Out on Refresh Failure

**Symptoms:**
- User remains logged in after refresh failure
- Tokens not cleared

**Solutions:**
1. Verify `_logoutUser()` is called on refresh failure
2. Check that tokens are being cleared from secure storage
3. Ensure error handler is properly rejecting the error

## Architecture

### Dependency Flow

```
authRepositoryProvider
    ↓
authInterceptorProvider (uses ref.read to break cycle)
    ↓
apiClientProvider
    ↓
authRemoteDataSourceProvider (uses ref.read to break cycle)
    ↓
authRepositoryProvider (completes cycle)
```

### Interceptor Chain Order

1. **ErrorInterceptor** (first) - Converts DioException to domain exceptions
2. **AuthInterceptor** (second) - Handles token injection and refresh
3. **LoggingInterceptor** (optional) - Logs requests/responses

**Important:** The order matters. `ErrorInterceptor` must be first to convert errors before `AuthInterceptor` processes them.

## Best Practices

### 1. Use Dependency Injection

Always use providers to get `ApiClient` and `AuthInterceptor`:

```dart
final container = ProviderContainer();
final apiClient = container.read(apiClientProvider);
```

### 2. Handle Refresh Failures

The interceptor automatically logs out users on refresh failure. Your UI should handle this gracefully:

```dart
try {
  final response = await apiClient.get('/api/data');
} on AuthException catch (e) {
  // User may have been logged out automatically
  // Navigate to login screen
}
```

### 3. Test Token Refresh

Regularly test the token refresh flow:
- Test with expired tokens
- Test with invalid refresh tokens
- Test concurrent requests

### 4. Monitor Refresh Frequency

If token refresh is happening too frequently:
- Check token expiration times
- Verify refresh token is being updated
- Review API token policies

## Common Patterns

### Making Authenticated Requests

```dart
// Token is automatically added by AuthInterceptor
final response = await apiClient.get('/api/user/profile');
```

### Handling Auth Errors

```dart
try {
  final response = await apiClient.post('/api/data', data: {...});
} on AuthException catch (e) {
  // Handle auth errors (excluding 401, which is handled automatically)
  if (e.code != '401') {
    // Show error message
  }
}
```

### Manual Token Refresh

In most cases, you don't need to manually refresh tokens. However, if needed:

```dart
final authRepository = container.read(authRepositoryProvider);
final result = await authRepository.refreshToken();

result.when(
  success: (newToken) {
    // Token refreshed successfully
  },
  failureCallback: (failure) {
    // Refresh failed, user will be logged out by interceptor
  },
);
```

## Security Considerations

### 1. Token Storage

- Tokens are stored in `SecureStorageService` (encrypted)
- Tokens are automatically cleared on refresh failure
- Refresh tokens are also stored securely

### 2. Request Retry

- Original request is retried with new token
- Request data and parameters are preserved
- No sensitive data is logged during retry

### 3. Endpoint Exclusion

- Auth endpoints are excluded to prevent loops
- Refresh endpoint itself is excluded
- Login/register endpoints bypass refresh

## Performance

### Token Refresh Overhead

- Token refresh adds minimal overhead (one additional request)
- Concurrent requests are queued efficiently
- Failed refreshes trigger immediate logout

### Request Queuing

- Requests are queued during refresh
- All queued requests are retried after successful refresh
- No request is lost during the refresh process

## Future Enhancements

Potential improvements for future versions:

1. **Configurable Retry Count:** Allow configuration of max retry attempts
2. **Refresh Token Rotation:** Implement refresh token rotation for enhanced security
3. **Token Refresh Callbacks:** Add callbacks for refresh success/failure
4. **Metrics:** Add metrics for token refresh frequency and success rate

## Related Documentation

- [Error Handling Migration](./ERROR_HANDLING_MIGRATION.md)
- [Secure Storage Migration](./SECURE_STORAGE_MIGRATION.md)
- [GROUP_4_PROMPT.md](../audit/prompts/GROUP_4_PROMPT.md)

## Support

For issues or questions:
1. Check this migration guide
2. Review test files for usage examples
3. Check the implementation checklist in GROUP_4_PROMPT.md

