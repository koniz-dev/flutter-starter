# Use Cases & Clean Architecture Migration Guide

**Last Updated:** December 2024

## Overview

This migration guide covers the completion of Clean Architecture implementation by adding missing use cases and updating the presentation layer to use use cases instead of repositories directly.

## Breaking Changes

### 1. AuthNotifier API Changes

**New Methods Added:**
- `register(String email, String password, String name)` - Register new user
- `logout()` - Logout current user
- `refreshToken()` - Refresh authentication token
- `getCurrentUser()` - Get current authenticated user
- `isAuthenticated()` - Check if user is authenticated

**Impact:** UI code can now use these new methods for complete authentication functionality.

### 2. Error State Management

**Before:**
```dart
// Error state was not always cleared before new operations
await authNotifier.login(email, password);
```

**After:**
```dart
// Error state is automatically cleared before new operations
await authNotifier.login(email, password);
// Error is cleared in the method itself
```

**Impact:** Error handling is now more consistent. Errors are automatically cleared before new operations.

## Migration Steps

### Step 1: Update UI to Use New Methods

If you were accessing the repository directly (which should not happen), update to use `AuthNotifier` methods:

**Before (if accessing repository directly - not recommended):**
```dart
final repository = ref.read(authRepositoryProvider);
final result = await repository.register(email, password, name);
```

**After:**
```dart
final authNotifier = ref.read(authNotifierProvider.notifier);
await authNotifier.register(email, password, name);
```

### Step 2: Use New AuthNotifier Methods

**Register:**
```dart
final authNotifier = ref.read(authNotifierProvider.notifier);
await authNotifier.register(
  'user@example.com',
  'password123',
  'User Name',
);

// Check result via state
final state = ref.read(authNotifierProvider);
if (state.user != null) {
  // Registration successful
} else if (state.error != null) {
  // Show error: state.error
}
```

**Logout:**
```dart
final authNotifier = ref.read(authNotifierProvider.notifier);
await authNotifier.logout();

// User is automatically cleared from state
final state = ref.read(authNotifierProvider);
expect(state.user, isNull);
```

**Get Current User:**
```dart
final authNotifier = ref.read(authNotifierProvider.notifier);
await authNotifier.getCurrentUser();

final state = ref.read(authNotifierProvider);
final user = state.user;
```

**Check Authentication:**
```dart
final authNotifier = ref.read(authNotifierProvider.notifier);
final isAuth = await authNotifier.isAuthenticated();

if (isAuth) {
  // User is authenticated
}
```

**Refresh Token:**
```dart
// Typically called automatically by AuthInterceptor
// But can be called manually if needed
final authNotifier = ref.read(authNotifierProvider.notifier);
await authNotifier.refreshToken();
```

### Step 3: Update State Listening

**Before:**
```dart
final authState = ref.watch(authNotifierProvider);
// Only had login functionality
```

**After:**
```dart
final authState = ref.watch(authNotifierProvider);
// Now has complete auth functionality:
// - user (User?)
// - isLoading (bool)
// - error (String?)
```

### Step 4: Handle Loading States

All methods now properly handle loading states:

```dart
final authState = ref.watch(authNotifierProvider);

if (authState.isLoading) {
  return CircularProgressIndicator();
}

if (authState.error != null) {
  return Text('Error: ${authState.error}');
}

if (authState.user != null) {
  return HomeScreen();
}
```

## New Features

### 1. Complete Use Case Layer

All authentication operations now have dedicated use cases:

- ✅ `LoginUseCase` - User login
- ✅ `RegisterUseCase` - User registration
- ✅ `LogoutUseCase` - User logout
- ✅ `RefreshTokenUseCase` - Token refresh
- ✅ `GetCurrentUserUseCase` - Get current user
- ✅ `IsAuthenticatedUseCase` - Check authentication status

### 2. Clean Architecture Compliance

**Before:**
- Presentation layer could access repository directly
- Business logic mixed with presentation logic

**After:**
- ✅ Presentation layer only uses use cases
- ✅ Business logic isolated in use cases
- ✅ Proper layer separation maintained

### 3. Improved State Management

**Features:**
- ✅ Automatic error clearing before operations
- ✅ Consistent loading state handling
- ✅ Proper state transitions for all operations

### 4. Use Case Providers

All use cases are available via Riverpod providers:

```dart
// Access use cases directly if needed (rare)
final loginUseCase = ref.read(loginUseCaseProvider);
final registerUseCase = ref.read(registerUseCaseProvider);
// ... etc
```

## Architecture

### Layer Separation

```
Presentation Layer (UI)
    ↓
AuthNotifier (State Management)
    ↓
Use Cases (Business Logic)
    ↓
Repository (Data Coordination)
    ↓
Data Sources (API/Cache)
```

### Use Case Pattern

Each use case follows the same pattern:

```dart
class UseCaseName {
  UseCaseName(this.repository);
  final AuthRepository repository;
  
  Future<Result<ReturnType>> call(...params) async {
    return repository.methodName(...params);
  }
}
```

## Testing

### Unit Tests

Comprehensive unit tests are available:

- ✅ `test/features/auth/domain/usecases/register_usecase_test.dart`
- ✅ `test/features/auth/presentation/providers/auth_provider_test.dart`

**Test Coverage:**
- ✅ All use cases tested
- ✅ All AuthNotifier methods tested
- ✅ Success and failure scenarios
- ✅ State transition tests
- ✅ Error handling tests
- ✅ Loading state tests

### Running Tests

```bash
# Test all use cases
flutter test test/features/auth/domain/usecases/

# Test AuthNotifier
flutter test test/features/auth/presentation/providers/auth_provider_test.dart

# Test integration
flutter test test/features/auth/integration/
```

## Best Practices

### 1. Always Use Use Cases

**❌ Don't:**
```dart
// Don't access repository directly from UI
final repository = ref.read(authRepositoryProvider);
await repository.login(email, password);
```

**✅ Do:**
```dart
// Use AuthNotifier (which uses use cases)
final authNotifier = ref.read(authNotifierProvider.notifier);
await authNotifier.login(email, password);
```

### 2. Watch State for UI Updates

**✅ Do:**
```dart
final authState = ref.watch(authNotifierProvider);

// React to state changes
if (authState.isLoading) {
  return LoadingWidget();
}
```

### 3. Handle Errors Properly

**✅ Do:**
```dart
final authState = ref.watch(authNotifierProvider);

if (authState.error != null) {
  // Show error to user
  showError(authState.error!);
}
```

### 4. Check Authentication Status

**✅ Do:**
```dart
final authNotifier = ref.read(authNotifierProvider.notifier);
final isAuth = await authNotifier.isAuthenticated();

if (isAuth) {
  // Navigate to authenticated screen
}
```

## Common Patterns

### Login Flow

```dart
class LoginScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final authNotifier = ref.read(authNotifierProvider.notifier);

    return Scaffold(
      body: authState.isLoading
          ? CircularProgressIndicator()
          : Column(
              children: [
                if (authState.error != null)
                  Text('Error: ${authState.error}'),
                ElevatedButton(
                  onPressed: () async {
                    await authNotifier.login(
                      emailController.text,
                      passwordController.text,
                    );
                  },
                  child: Text('Login'),
                ),
              ],
            ),
    );
  }
}
```

### Registration Flow

```dart
await authNotifier.register(
  emailController.text,
  passwordController.text,
  nameController.text,
);

// Check result
final state = ref.read(authNotifierProvider);
if (state.user != null) {
  // Navigate to home
} else if (state.error != null) {
  // Show error
}
```

### Logout Flow

```dart
await authNotifier.logout();

// State automatically cleared
// Navigate to login screen
```

## Troubleshooting

### Issue: State Not Updating

**Symptoms:**
- UI not reflecting state changes
- Loading state stuck

**Solutions:**
1. Verify you're watching `authNotifierProvider` in UI
2. Check that operations complete (await the future)
3. Verify error handling doesn't swallow exceptions

### Issue: Error State Not Clearing

**Symptoms:**
- Old errors persist after new operations

**Solutions:**
1. Verify you're using the updated AuthNotifier
2. Check that `error: null` is set in success handlers
3. Errors are automatically cleared before new operations

### Issue: Use Case Not Found

**Symptoms:**
- Provider not found errors
- Import errors

**Solutions:**
1. Verify all use case providers are in `providers.dart`
2. Check imports in files using use cases
3. Ensure providers are registered before use

## Related Documentation

- [Error Handling Migration](./ERROR_HANDLING_MIGRATION.md)
- [Token Refresh Migration](./TOKEN_REFRESH_MIGRATION.md)
- [GROUP_5_PROMPT.md](../audit/prompts/GROUP_5_PROMPT.md)

## Support

For issues or questions:
1. Check this migration guide
2. Review test files for usage examples
3. Check the implementation checklist in GROUP_5_PROMPT.md

