# Group 4: Token Refresh & Auth Interceptor - Self-Contained Implementation Prompt

**Last Updated:** November 15, 2025

## Context

I need to implement automatic token refresh logic in the AuthInterceptor. Currently, when the API returns 401 Unauthorized, the interceptor has a TODO comment but no implementation. This means tokens won't be refreshed automatically, causing authentication failures that require manual re-login.

## Current State

### Problems:
1. **Token refresh incomplete** - AuthInterceptor has TODO but no implementation
2. **No automatic retry** - 401 errors don't trigger token refresh
3. **Manual re-login required** - Users must manually log in again when token expires
4. **Poor UX** - Seamless token refresh should be transparent to users

### Current Files:
- `lib/core/network/interceptors/auth_interceptor.dart` - Has TODO for token refresh (line 36-38)
- `lib/features/auth/data/repositories/auth_repository_impl.dart` - Has `refreshToken()` method
- `lib/core/di/providers.dart` - Has auth repository provider

## Requirements

### 1. Implement Token Refresh in AuthInterceptor
**File:** `lib/core/network/interceptors/auth_interceptor.dart`

- Handle 401 Unauthorized responses in `onError`
- Call `refreshToken()` from repository
- Retry original request with new token
- Handle refresh failure (logout user, clear cache)

### 2. Add Retry Logic
- Store original request
- Refresh token
- Update Authorization header with new token
- Retry original request
- Prevent infinite retry loops

### 3. Handle Refresh Failure
- If refresh fails, clear auth state
- Navigate to login screen (if possible)
- Show appropriate error message
- Clear all cached tokens

### 4. Prevent Concurrent Refresh
- Only one refresh operation at a time
- Queue other requests during refresh
- Retry all queued requests after successful refresh

## Implementation Details

### AuthInterceptor Structure:
```dart
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.storageService,
    required this.authRepository,
  });

  final StorageService storageService;
  final AuthRepository authRepository;
  
  bool _isRefreshing = false;
  final List<_PendingRequest> _pendingRequests = [];

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Handle 401 Unauthorized
    if (err.response?.statusCode == 401) {
      return _handle401Error(err, handler);
    }
    super.onError(err, handler);
  }

  Future<void> _handle401Error(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Prevent infinite retry
    final requestOptions = err.requestOptions;
    if (requestOptions.headers['X-Retry-Count'] == '1') {
      // Already retried, logout user
      await _logoutUser();
      return handler.reject(err);
    }

    // Refresh token
    if (_isRefreshing) {
      // Wait for ongoing refresh
      return _queueRequest(err, handler);
    }

    _isRefreshing = true;
    
    try {
      final result = await authRepository.refreshToken();
      
      result.when(
        success: (newToken) async {
          // Update token in storage
          await storageService.setString(AppConstants.tokenKey, newToken);
          
          // Retry original request
          final opts = requestOptions.copyWith(
            headers: {
              ...requestOptions.headers,
              'Authorization': 'Bearer $newToken',
              'X-Retry-Count': '1',
            },
          );
          
          // Retry request
          final response = await err.dio.request(
            opts.path,
            options: Options(
              method: opts.method,
              headers: opts.headers,
            ),
            data: opts.data,
            queryParameters: opts.queryParameters,
          );
          
          _isRefreshing = false;
          _retryPendingRequests(newToken);
          
          return handler.resolve(response);
        },
        failure: (message, code) async {
          _isRefreshing = false;
          await _logoutUser();
          return handler.reject(err);
        },
      );
    } catch (e) {
      _isRefreshing = false;
      await _logoutUser();
      return handler.reject(err);
    }
  }

  Future<void> _logoutUser() async {
    await storageService.remove(AppConstants.tokenKey);
    await storageService.remove(AppConstants.refreshTokenKey);
    await storageService.remove(AppConstants.userDataKey);
    // Navigate to login if possible
  }

  void _queueRequest(DioException err, ErrorInterceptorHandler handler) {
    _pendingRequests.add(_PendingRequest(err, handler));
  }

  void _retryPendingRequests(String newToken) {
    // Retry all pending requests
    for (final pending in _pendingRequests) {
      // Retry logic
    }
    _pendingRequests.clear();
  }
}
```

### Provider Update:
```dart
// In providers.dart
final authInterceptorProvider = Provider<AuthInterceptor>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthInterceptor(
    storageService: storageService,
    authRepository: authRepository,
  );
});
```

## Testing Requirements

1. **Test successful token refresh**
   - 401 triggers refresh
   - Original request retried with new token
   - User doesn't notice the refresh

2. **Test refresh failure**
   - Refresh fails → logout user
   - Tokens cleared
   - Error handled gracefully

3. **Test infinite retry prevention**
   - Max retry count enforced
   - Prevents infinite loops
   - Logout after max retries

4. **Test concurrent requests**
   - Multiple 401s during refresh
   - Requests queued properly
   - All retried after refresh

5. **Test refresh token expiry**
   - Refresh token expired
   - Proper logout flow
   - User-friendly error

## Success Criteria

- ✅ 401 errors trigger automatic token refresh
- ✅ Original request retried with new token
- ✅ Refresh failure handled gracefully
- ✅ No infinite retry loops
- ✅ Concurrent requests handled properly
- ✅ User experience is seamless
- ✅ All tests pass

## Files to Modify

1. `lib/core/network/interceptors/auth_interceptor.dart` - Implement refresh logic
2. `lib/core/di/providers.dart` - Update AuthInterceptor provider
3. `lib/core/network/api_client.dart` - May need to update interceptor usage

## Dependencies

- Group 1 (Error Handling) - For proper exception handling
- Group 3 (Storage) - For secure token storage
- `lib/features/auth/domain/repositories/auth_repository.dart` - For refreshToken method

---

## Common Mistakes to Avoid

### ❌ Don't create infinite retry loops
- Track retry count
- Max retry limit (e.g., 1)
- Logout after max retries

### ❌ Don't refresh on every 401
- Check if refresh token exists
- Don't refresh if already refreshing
- Handle refresh token expiry

### ❌ Don't lose original request
- Store request options
- Preserve request data
- Retry with same parameters

### ❌ Don't block other requests
- Queue requests during refresh
- Retry all after successful refresh
- Handle concurrent scenarios

### ❌ Don't ignore refresh failures
- Logout user on failure
- Clear all tokens
- Show appropriate error

---

## Edge Cases to Handle

### 1. Refresh Token Expired
- Refresh token itself expired
- Can't refresh → logout
- Clear all auth state

### 2. Network Error During Refresh
- Refresh request fails
- Handle as network error
- Don't retry original request

### 3. Multiple Concurrent 401s
- Multiple requests get 401 simultaneously
- Only one refresh operation
- Queue other requests
- Retry all after refresh

### 4. Refresh Succeeds But Retry Fails
- Token refreshed but original request fails again
- Don't refresh again (already retried)
- Return error to user

### 5. Request Cancellation
- User cancels request
- Don't refresh for cancelled requests
- Handle cancellation gracefully

### 6. Different Auth Endpoints
- Some endpoints shouldn't trigger refresh
- Login/register endpoints
- Whitelist endpoints that bypass refresh

### 7. Token Refresh Race Condition
- Multiple threads trying to refresh
- Use lock/mutex pattern
- Ensure single refresh operation

---

## Expected Deliverables

Provide responses in this order:

### 1. Updated AuthInterceptor (Complete Code)

**1.1. `lib/core/network/interceptors/auth_interceptor.dart`**
- Complete implementation with token refresh
- Retry logic
- Concurrent request handling
- Error handling

### 2. Updated Providers (Changes Only)

**2.1. `lib/core/di/providers.dart`**
- Show only the changes
- AuthInterceptor provider update
- Clear before/after context

### 3. Updated ApiClient (Changes Only, If Needed)

**3.1. `lib/core/network/api_client.dart`**
- Show only the changes if any
- Interceptor usage updates
- Clear context

### 4. Test File Examples (At Least 2)

**4.1. `test/core/network/interceptors/auth_interceptor_test.dart`**
- Test successful refresh and retry
- Test refresh failure
- Test infinite retry prevention
- Test concurrent requests

**4.2. `test/features/auth/integration/token_refresh_test.dart`**
- Integration test for token refresh flow
- End-to-end test
- Real API interaction test

### 5. Migration Notes

**5.1. Breaking Changes**
- AuthInterceptor constructor changes
- Provider updates

**5.2. Migration Steps**
- Update provider usage
- Test token refresh flow
- Verify logout on failure

---

## Implementation Checklist

Before submitting, verify:

- [ ] Token refresh implemented in onError
- [ ] 401 errors trigger refresh
- [ ] Original request retried
- [ ] Infinite retry prevention
- [ ] Concurrent requests handled
- [ ] Refresh failure handled
- [ ] User logged out on failure
- [ ] Tokens cleared on failure
- [ ] All tests pass
- [ ] Edge cases handled
- [ ] Error messages user-friendly

