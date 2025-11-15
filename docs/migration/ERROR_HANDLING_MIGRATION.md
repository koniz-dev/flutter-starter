# Error Handling System Migration Guide

## Overview

This document describes the migration from generic error handling to a complete typed error handling system with automatic DioException conversion and typed failures.

## Breaking Changes

### 1. ResultFailure Type Change

**Before:**
```dart
ResultFailure<String>('Error message', code: 'ERROR_CODE')
```

**After:**
```dart
ResultFailure<String>(ServerFailure('Error message', code: 'ERROR_CODE'))
```

The `ResultFailure` constructor now requires a `Failure` object instead of a message and optional code.

### 2. Result.when() Method Signature

**Before:**
```dart
result.when(
  success: (data) => handleSuccess(data),
  failure: (message, code) => handleFailure(message, code),
);
```

**After:**
```dart
result.when(
  success: (data) => handleSuccess(data),
  failureCallback: (failure) => handleFailure(failure),
);
```

The failure callback now receives a `Failure` object instead of separate message and code parameters.

**Backward Compatibility:**
A deprecated `whenLegacy()` method is available for backward compatibility:
```dart
result.whenLegacy(
  success: (data) => handleSuccess(data),
  failure: (message, code) => handleFailure(message, code),
);
```

### 3. Repository Return Types

Repositories now return typed failures instead of generic `ResultFailure` with message/code.

**Before:**
```dart
return ResultFailure('Error message', code: 'ERROR_CODE');
```

**After:**
```dart
return ResultFailure(ServerFailure('Error message', code: 'ERROR_CODE'));
```

## Migration Steps

### Step 1: Update UI Layer Error Handling

**Before:**
```dart
final result = await repository.login(email, password);
result.when(
  success: (user) => navigateToHome(),
  failure: (message, code) => showError(message),
);
```

**After:**
```dart
final result = await repository.login(email, password);
result.when(
  success: (user) => navigateToHome(),
  failureCallback: (failure) {
    switch (failure) {
      case ServerFailure():
        showError('Server error: ${failure.message}');
      case NetworkFailure():
        showError('Network error: ${failure.message}');
      case AuthFailure():
        showError('Authentication failed: ${failure.message}');
      default:
        showError(failure.message);
    }
  },
);
```

### Step 2: Update Data Source Error Handling

**Before:**
```dart
try {
  final response = await apiClient.post('/endpoint', data: data);
  if (response.statusCode == 200) {
    return Model.fromJson(response.data);
  } else {
    throw ServerException('Error', statusCode: response.statusCode);
  }
} catch (e) {
  throw ServerException('Failed: $e');
}
```

**After:**
```dart
// Error interceptor handles conversion automatically
// Dio throws for non-2xx status codes
final response = await apiClient.post('/endpoint', data: data);
return Model.fromJson(response.data);
```

### Step 3: Update Repository Error Handling

**Before:**
```dart
try {
  final data = await remoteDataSource.getData();
  return Success(data);
} on ServerException catch (e) {
  return ResultFailure(e.message, code: e.code);
} on NetworkException catch (e) {
  return ResultFailure(e.message, code: e.code);
} on Exception catch (e) {
  return ResultFailure('Unexpected error: $e');
}
```

**After:**
```dart
import 'package:flutter_starter/core/errors/exception_to_failure_mapper.dart';

try {
  final data = await remoteDataSource.getData();
  return Success(data);
} on AppException catch (e) {
  return ResultFailure(ExceptionToFailureMapper.map(e));
} on Exception catch (e) {
  return ResultFailure(ExceptionToFailureMapper.map(e));
}
```

### Step 4: Update Error Display Logic

**Before:**
```dart
if (result.isFailure) {
  final message = result.errorOrNull ?? 'Unknown error';
  showError(message);
}
```

**After:**
```dart
if (result.isFailure) {
  final failure = result.failureOrNull;
  if (failure != null) {
    switch (failure) {
      case ServerFailure():
        showServerError(failure);
      case NetworkFailure():
        showNetworkError(failure);
      case AuthFailure():
        showAuthError(failure);
      default:
        showError(failure.message);
    }
  }
}
```

## New Features

### 1. Automatic DioException Conversion

All `DioException` errors are automatically converted to domain exceptions by the `ErrorInterceptor`. No manual conversion needed in data sources.

### 2. Typed Failures

Failures are now strongly typed, allowing for pattern matching and type-safe error handling:

```dart
result.when(
  success: (data) => handleSuccess(data),
  failureCallback: (failure) {
    if (failure is ServerFailure) {
      // Handle server errors
    } else if (failure is NetworkFailure) {
      // Handle network errors
    }
  },
);
```

### 3. Error Message Extraction

The `DioExceptionMapper` automatically extracts user-friendly error messages from API responses, supporting various response formats:
- `{ "message": "..." }`
- `{ "error": { "message": "..." } }`
- `{ "error_message": "..." }`
- String responses
- Status code-based default messages

## Backward Compatibility

### Available Legacy Methods

1. **`whenLegacy()`** - Deprecated but available for backward compatibility
2. **`message` and `code` getters** - Available on `ResultFailure` for convenience

### Migration Timeline

- **Phase 1 (Current)**: New error handling system implemented
- **Phase 2 (Recommended)**: Migrate UI layer to use typed failures
- **Phase 3 (Future)**: Remove deprecated `whenLegacy()` method

## Testing

### Unit Tests

Comprehensive unit tests are available:
- `test/core/errors/dio_exception_mapper_test.dart`
- `test/core/errors/exception_to_failure_mapper_test.dart`

### Running Tests

```bash
flutter test test/core/errors/
```

## Common Patterns

### Pattern Matching on Failures

```dart
result.when(
  success: (data) => data,
  failureCallback: (failure) => switch (failure) {
    ServerFailure(:final message, :final code) => 
      handleServerError(message, code),
    NetworkFailure(:final message) => 
      handleNetworkError(message),
    AuthFailure() => 
      handleAuthError(),
    _ => handleUnknownError(),
  },
);
```

### Checking Failure Type

```dart
if (result.isFailure) {
  final failure = result.failureOrNull;
  if (failure is ServerFailure) {
    // Handle server error
  } else if (failure is NetworkFailure) {
    // Handle network error
  }
}
```

### Accessing Error Information

```dart
// Still works for backward compatibility
final message = result.errorOrNull;
final code = result.code; // Available on ResultFailure

// New typed approach
final failure = result.failureOrNull;
if (failure != null) {
  final message = failure.message;
  final code = failure.code;
}
```

## Notes

- The `ErrorInterceptor` must be first in the Dio interceptor chain
- All DioExceptions are automatically converted to domain exceptions
- Unknown exceptions are mapped to `UnknownFailure`
- Error messages are preserved throughout the conversion chain
- Status codes are preserved in `ServerException` and can be accessed via the failure

