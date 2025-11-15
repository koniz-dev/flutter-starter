# Auth Use Case APIs

Authentication use cases for business logic operations.

## Overview

Use cases encapsulate single business operations and orchestrate repository calls. All use cases follow the same pattern: they take a repository and expose a `call` method.

---

## LoginUseCase

Handles user login business logic.

**Location:** `lib/features/auth/domain/usecases/login_usecase.dart`

### Constructor

```dart
/// Creates a [LoginUseCase] with the given [repository]
LoginUseCase(this.repository);
```

### Properties

- `final AuthRepository repository` - Authentication repository for login operations

### Methods

```dart
/// Executes login with [email] and [password]
/// 
/// Parameters:
/// - [email]: User's email address
/// - [password]: User's password
/// 
/// Returns:
/// - [Future<Result<User>>]: Success with User entity, or Failure with error details
/// 
/// Example:
/// ```dart
/// final useCase = LoginUseCase(authRepository);
/// final result = await useCase('user@example.com', 'password123');
/// result.when(
///   success: (user) => navigateToHome(),
///   failureCallback: (failure) => showError(failure.message),
/// );
/// ```
Future<Result<User>> call(String email, String password);
```

---

## RegisterUseCase

Handles user registration business logic.

**Location:** `lib/features/auth/domain/usecases/register_usecase.dart`

### Constructor

```dart
/// Creates a [RegisterUseCase] with the given [repository]
RegisterUseCase(this.repository);
```

### Properties

- `final AuthRepository repository` - Authentication repository for registration operations

### Methods

```dart
/// Executes registration with [email], [password], and [name]
/// 
/// Parameters:
/// - [email]: User's email address
/// - [password]: User's password
/// - [name]: User's full name
/// 
/// Returns:
/// - [Future<Result<User>>]: Success with User entity, or Failure with error details
/// 
/// Example:
/// ```dart
/// final useCase = RegisterUseCase(authRepository);
/// final result = await useCase('user@example.com', 'password123', 'John Doe');
/// ```
Future<Result<User>> call(String email, String password, String name);
```

---

## LogoutUseCase

Handles user logout business logic.

**Location:** `lib/features/auth/domain/usecases/logout_usecase.dart`

### Constructor

```dart
/// Creates a [LogoutUseCase] with the given [repository]
LogoutUseCase(this.repository);
```

### Properties

- `final AuthRepository repository` - Authentication repository for logout operations

### Methods

```dart
/// Executes logout for the current user
/// 
/// Returns:
/// - [Future<Result<void>>]: Success if logout succeeded, or Failure with error details
/// 
/// Example:
/// ```dart
/// final useCase = LogoutUseCase(authRepository);
/// final result = await useCase();
/// if (result.isSuccess) {
///   navigateToLogin();
/// }
/// ```
Future<Result<void>> call();
```

---

## GetCurrentUserUseCase

Retrieves the currently authenticated user.

**Location:** `lib/features/auth/domain/usecases/get_current_user_usecase.dart`

### Constructor

```dart
/// Creates a [GetCurrentUserUseCase] with the given [repository]
GetCurrentUserUseCase(this.repository);
```

### Properties

- `final AuthRepository repository` - Authentication repository for getting current user

### Methods

```dart
/// Executes getting the current authenticated user
/// 
/// Returns:
/// - [Future<Result<User?>>]: Success with User entity if authenticated, null if not,
///   or Failure with error details
/// 
/// Example:
/// ```dart
/// final useCase = GetCurrentUserUseCase(authRepository);
/// final result = await useCase();
/// result.when(
///   success: (user) {
///     if (user != null) {
///       displayUserProfile(user);
///     }
///   },
///   failureCallback: (failure) => handleError(failure),
/// );
/// ```
Future<Result<User?>> call();
```

---

## IsAuthenticatedUseCase

Checks if the user is currently authenticated.

**Location:** `lib/features/auth/domain/usecases/is_authenticated_usecase.dart`

### Constructor

```dart
/// Creates an [IsAuthenticatedUseCase] with the given [repository]
IsAuthenticatedUseCase(this.repository);
```

### Properties

- `final AuthRepository repository` - Authentication repository for checking authentication status

### Methods

```dart
/// Executes checking if the user is authenticated
/// 
/// Returns:
/// - [Future<Result<bool>>]: Success with true if authenticated, false otherwise,
///   or Failure with error details
/// 
/// Example:
/// ```dart
/// final useCase = IsAuthenticatedUseCase(authRepository);
/// final result = await useCase();
/// if (result.isSuccess && result.dataOrNull == true) {
///   // User is authenticated, show home screen
/// } else {
///   // User is not authenticated, show login screen
/// }
/// ```
Future<Result<bool>> call();
```

---

## RefreshTokenUseCase

Refreshes the authentication token.

**Location:** `lib/features/auth/domain/usecases/refresh_token_usecase.dart`

### Constructor

```dart
/// Creates a [RefreshTokenUseCase] with the given [repository]
RefreshTokenUseCase(this.repository);
```

### Properties

- `final AuthRepository repository` - Authentication repository for token refresh operations

### Methods

```dart
/// Executes token refresh for the current user
/// 
/// Returns:
/// - [Future<Result<String>>]: Success with new access token, or Failure with error details
/// 
/// Example:
/// ```dart
/// final useCase = RefreshTokenUseCase(authRepository);
/// final result = await useCase();
/// result.when(
///   success: (token) {
///     // Token refreshed successfully
///     updateTokenInStorage(token);
///   },
///   failureCallback: (failure) {
///     // Token refresh failed, logout user
///     logout();
///   },
/// );
/// ```
Future<Result<String>> call();
```

---

## Usage Pattern

All use cases follow the same pattern:

1. Access via provider
2. Call the use case
3. Handle result with pattern matching

```dart
// Access use case via provider
final loginUseCase = ref.read(loginUseCaseProvider);

// Call use case
final result = await loginUseCase('user@example.com', 'password');

// Handle result
result.when(
  success: (user) {
    // Handle success
  },
  failureCallback: (failure) {
    // Handle failure
  },
);
```

---

## Related APIs

- [Repositories](repositories.md) - Repository interfaces used by use cases
- [Providers](providers.md) - Dependency injection setup
- [Examples - Common Patterns](../../examples/common-patterns.md) - Usage examples

