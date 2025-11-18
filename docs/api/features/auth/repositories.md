# Auth Repository APIs

Authentication repository interfaces for the domain layer.

## Overview

The authentication repository defines the contract for all authentication operations in the domain layer.

---

## AuthRepository

Authentication repository interface defining all authentication operations.

**Location:** `lib/features/auth/domain/repositories/auth_repository.dart`

### Methods

#### login

```dart
/// Login with email and password
/// 
/// Parameters:
/// - [email]: User's email address
/// - [password]: User's password
/// 
/// Returns:
/// - [Result<User>]: Success with User entity, or Failure with error details
/// 
/// Example:
/// ```dart
/// final result = await authRepository.login('user@example.com', 'password123');
/// result.when(
///   success: (user) => print('Logged in: ${user.email}'),
///   failureCallback: (failure) => print('Error: ${failure.message}'),
/// );
/// ```
Future<Result<User>> login(String email, String password);
```

#### register

```dart
/// Register new user
/// 
/// Parameters:
/// - [email]: User's email address
/// - [password]: User's password
/// - [name]: User's full name
/// 
/// Returns:
/// - [Result<User>]: Success with User entity, or Failure with error details
/// 
/// Example:
/// ```dart
/// final result = await authRepository.register(
///   'user@example.com',
///   'password123',
///   'John Doe',
/// );
/// ```
Future<Result<User>> register(String email, String password, String name);
```

#### logout

```dart
/// Logout current user
/// 
/// Clears all authentication data from local storage and invalidates session.
/// 
/// Returns:
/// - [Result<void>]: Success if logout succeeded, or Failure with error details
/// 
/// Example:
/// ```dart
/// final result = await authRepository.logout();
/// if (result.isSuccess) {
///   // Navigate to login screen
/// }
/// ```
Future<Result<void>> logout();
```

#### getCurrentUser

```dart
/// Get current user
/// 
/// Retrieves the currently authenticated user from local cache.
/// 
/// Returns:
/// - [Result<User?>]: Success with User entity if authenticated, null if not,
///   or Failure with error details
/// 
/// Example:
/// ```dart
/// final result = await authRepository.getCurrentUser();
/// result.when(
///   success: (user) {
///     if (user != null) {
///       print('Current user: ${user.email}');
///     } else {
///       print('No user logged in');
///     }
///   },
///   failureCallback: (failure) => print('Error: ${failure.message}'),
/// );
/// ```
Future<Result<User?>> getCurrentUser();
```

#### isAuthenticated

```dart
/// Check if user is authenticated
/// 
/// Returns:
/// - [Result<bool>]: Success with true if authenticated, false otherwise,
///   or Failure with error details
/// 
/// Example:
/// ```dart
/// final result = await authRepository.isAuthenticated();
/// if (result.isSuccess && result.dataOrNull == true) {
///   // User is authenticated
/// }
/// ```
Future<Result<bool>> isAuthenticated();
```

#### refreshToken

```dart
/// Refresh authentication token
/// 
/// Refreshes the access token using the stored refresh token.
/// 
/// Returns:
/// - [Result<String>]: Success with new access token, or Failure with error details
/// 
/// Example:
/// ```dart
/// final result = await authRepository.refreshToken();
/// result.when(
///   success: (token) => print('New token: $token'),
///   failureCallback: (failure) => print('Token refresh failed: ${failure.message}'),
/// );
/// ```
Future<Result<String>> refreshToken();
```

---

## Implementation

The repository is implemented by `AuthRepositoryImpl` in the data layer, which coordinates between:
- `AuthRemoteDataSource` - For API calls
- `AuthLocalDataSource` - For local caching

See [Providers](providers.md) for dependency injection setup.

---

## Related APIs

- [Use Cases](usecases.md) - Use cases that use this repository
- [Providers](providers.md) - Dependency injection setup
- [Models](models.md) - Data models used by the repository

