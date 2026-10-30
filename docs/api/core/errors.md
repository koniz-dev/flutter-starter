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
- `PermissionException` - Permission denied errors
- `NotFoundException` - A resource that does not exist

**Example:**
```dart
throw ServerException('Server error', code: '500', statusCode: 500);
throw NetworkException('No internet connection');
throw AuthException('Invalid credentials', code: '401');
```

### Exception to Failure Mapping

Exceptions are automatically converted to Failures by `ExceptionToFailureMapper`:

- `ServerException` → by HTTP status:
  - 401 → `AuthFailure`
  - 403 → `PermissionFailure`
  - 404 → `NotFoundFailure`
  - 422 → `ValidationFailure`
  - any other status → `ServerFailure`, carrying the `statusCode`
- `NetworkException` → `NetworkFailure`
- `CacheException` → `CacheFailure`
- `ValidationException` → `ValidationFailure`
- `AuthException` → `AuthFailure`
- `PermissionException` → `PermissionFailure`
- `NotFoundException` → `NotFoundFailure`
- Other exceptions → `UnknownFailure`

So a UI can tell a rejected login (401, `AuthFailure`) from a missing record (404, `NotFoundFailure`) or a server fault (`ServerFailure`) by type, without matching on message text.

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
- `NotFoundFailure` - A resource that does not exist
- `UnknownFailure` - Unclassified errors

**Example:**
```dart
final failure = ServerFailure('Server error', code: '500');
final result = ResultFailure<User>(failure);
```

### Failure Types

#### `ServerFailure`

Represents API/server errors whose status has no typed failure of its own (5xx, 400, 408, 429 and so on). `statusCode` is part of its equality, so a 404 and a 500 with the same message are not equal - and a 404 is a `NotFoundFailure` anyway.

<!-- symbol: lib/core/errors/failures.dart ServerFailure -->
<!-- signature: lib/core/errors/failures.dart ServerFailure -->
```dart
const ServerFailure(String message, {String? code, int? statusCode});
```

**Example:**
```dart
final failure = ServerFailure('Internal server error', code: '500');
```

#### `NetworkFailure`

Represents network connectivity issues.

<!-- signature: lib/core/errors/failures.dart NetworkFailure -->
```dart
const NetworkFailure(String message, {String? code});
```

**Example:**
```dart
final failure = NetworkFailure('No internet connection');
```

#### `CacheFailure`

Represents local storage errors.

<!-- signature: lib/core/errors/failures.dart CacheFailure -->
```dart
const CacheFailure(String message, {String? code});
```

**Example:**
```dart
final failure = CacheFailure('Failed to save data', code: 'STORAGE_ERROR');
```

#### `AuthFailure`

Represents authentication/authorization errors.

<!-- signature: lib/core/errors/failures.dart AuthFailure -->
```dart
const AuthFailure(String message, {String? code});
```

**Example:**
```dart
final failure = AuthFailure('Invalid credentials', code: '401');
```

#### `ValidationFailure`

Represents input validation errors.

<!-- signature: lib/core/errors/failures.dart ValidationFailure -->
```dart
const ValidationFailure(String message, {String? code});
```

**Example:**
```dart
final failure = ValidationFailure('Email is required', code: 'VALIDATION_ERROR');
```

#### `PermissionFailure`

Represents permission denied errors.

<!-- signature: lib/core/errors/failures.dart PermissionFailure -->
```dart
const PermissionFailure(String message, {String? code});
```

**Example:**
```dart
final failure = PermissionFailure('Camera permission denied');
```

#### `NotFoundFailure`

Represents a resource that does not exist. An HTTP 404 maps here.

<!-- signature: lib/core/errors/failures.dart NotFoundFailure -->
```dart
const NotFoundFailure(String message, {String? code});
```

**Example:**
```dart
final failure = NotFoundFailure('Task not found');
```

#### `UnknownFailure`

Represents unclassified errors.

<!-- signature: lib/core/errors/failures.dart UnknownFailure -->
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

Let `ExceptionToFailureMapper` choose the failure, as the repositories do.
Mapping by hand loses what it knows: a 401 `ServerException` becomes an
`AuthFailure`, a 404 a `NotFoundFailure`, and so on (see above).

```dart
// In repository implementation
try {
  // Operation that may throw
} on Exception catch (e) {
  return ResultFailure(ExceptionToFailureMapper.map(e));
}
```

<!-- symbol: lib/core/errors/exception_to_failure_mapper.dart ExceptionToFailureMapper.map -->

---

## Related APIs

- [Utils - Result](utils.md#result) - Result type for handling success/failure
- [Network](network.md) - Network error handling
- [Storage](storage.md) - Storage error handling


