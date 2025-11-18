# Error Handling APIs

Exception and Failure types for type-safe error handling.

## Overview

The error handling system uses two main types:
- **Exceptions**: Thrown in the data layer (network, storage operations)
- **Failures**: Domain-level error representations used in Result types

## Exceptions

Exceptions are thrown in the data layer and converted to Failures for the domain layer.

### `AppException`

Base exception class for all application exceptions.

**Location:** `lib/core/errors/exceptions.dart`

**Properties:**
- `final String message` - Error message describing what went wrong
- `final String? code` - Optional error code for programmatic error handling

**Subtypes:**
- `ServerException` - API/server errors (includes `statusCode`)
- `NetworkException` - Network connectivity issues
- `CacheException` - Local storage errors
- `ValidationException` - Input validation errors
- `AuthException` - Authentication/authorization errors

**Example:**
```dart
throw ServerException('Server error', code: '500', statusCode: 500);
throw NetworkException('No internet connection');
throw AuthException('Invalid credentials', code: '401');
```

### Exception to Failure Mapping

Exceptions are automatically converted to Failures by `ExceptionToFailureMapper`:

- `ServerException` → `ServerFailure`
- `NetworkException` → `NetworkFailure`
- `CacheException` → `CacheFailure`
- `ValidationException` → `ValidationFailure`
- `AuthException` → `AuthFailure`
- Other exceptions → `UnknownFailure`

---

## Failures

Failures represent typed error information in the domain layer and are used within `ResultFailure`.

### `Failure`

Base class for all failures in the domain layer.

**Location:** `lib/core/errors/failures.dart`

**Properties:**
- `final String message` - Error message describing what went wrong
- `final String? code` - Optional error code for programmatic error handling

**Subtypes:**
- `ServerFailure` - API/server errors
- `NetworkFailure` - Network connectivity issues
- `CacheFailure` - Local storage errors
- `AuthFailure` - Authentication/authorization errors
- `ValidationFailure` - Input validation errors
- `PermissionFailure` - Permission denied errors
- `UnknownFailure` - Unclassified errors

**Example:**
```dart
final failure = ServerFailure('Server error', code: '500');
final result = ResultFailure<User>(failure);
```

### Failure Types

#### `ServerFailure`

Represents API/server errors.

```dart
const ServerFailure(String message, {String? code});
```

**Example:**
```dart
final failure = ServerFailure('Internal server error', code: '500');
```

#### `NetworkFailure`

Represents network connectivity issues.

```dart
const NetworkFailure(String message, {String? code});
```

**Example:**
```dart
final failure = NetworkFailure('No internet connection');
```

#### `CacheFailure`

Represents local storage errors.

```dart
const CacheFailure(String message, {String? code});
```

**Example:**
```dart
final failure = CacheFailure('Failed to save data', code: 'STORAGE_ERROR');
```

#### `AuthFailure`

Represents authentication/authorization errors.

```dart
const AuthFailure(String message, {String? code});
```

**Example:**
```dart
final failure = AuthFailure('Invalid credentials', code: '401');
```

#### `ValidationFailure`

Represents input validation errors.

```dart
const ValidationFailure(String message, {String? code});
```

**Example:**
```dart
final failure = ValidationFailure('Email is required', code: 'VALIDATION_ERROR');
```

#### `PermissionFailure`

Represents permission denied errors.

```dart
const PermissionFailure(String message, {String? code});
```

**Example:**
```dart
final failure = PermissionFailure('Camera permission denied');
```

#### `UnknownFailure`

Represents unclassified errors.

```dart
const UnknownFailure(String message, {String? code});
```

**Example:**
```dart
final failure = UnknownFailure('An unexpected error occurred');
```

---

## Usage Patterns

### Handling Failures in Result

```dart
final result = await loginUseCase('user@example.com', 'password');
result.when(
  success: (user) {
    // Handle success
  },
  failureCallback: (failure) {
    if (failure is AuthFailure) {
      // Handle auth error
      showError('Authentication failed: ${failure.message}');
    } else if (failure is NetworkFailure) {
      // Handle network error
      showError('Network error: ${failure.message}');
    } else if (failure is ServerFailure) {
      // Handle server error
      showError('Server error: ${failure.message}');
    } else {
      // Handle other errors
      showError('Error: ${failure.message}');
    }
  },
);
```

### Pattern Matching on Failure Types

```dart
result.when(
  success: (data) => handleSuccess(data),
  failureCallback: (failure) {
    switch (failure) {
      case ServerFailure(:final message, :final code):
        print('Server error: $message (code: $code)');
        break;
      case NetworkFailure(:final message):
        print('Network error: $message');
        break;
      case AuthFailure(:final message):
        print('Auth error: $message');
        logout();
        break;
      default:
        print('Error: ${failure.message}');
    }
  },
);
```

### Creating Failures

```dart
// In repository implementation
try {
  // Operation that may throw
} on ServerException catch (e) {
  return ResultFailure(ServerFailure(e.message, code: e.code));
} on NetworkException catch (e) {
  return ResultFailure(NetworkFailure(e.message, code: e.code));
} on Exception catch (e) {
  return ResultFailure(UnknownFailure(e.toString()));
}
```

---

## Related APIs

- [Utils - Result](utils.md#result) - Result type for handling success/failure
- [Network](network.md) - Network error handling
- [Storage](storage.md) - Storage error handling

