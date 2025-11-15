# Error Handling Strategy

## Overview

This document describes the error handling strategy for the Flutter Starter project. It outlines how errors flow through the application layers, from network exceptions to user-facing error messages.

## Architecture Decision Record (ADR)

**Status:** Accepted  
**Date:** 2025-11-15  
**Context:** Need a consistent error handling strategy across all layers  
**Decision:** Use typed failures with exception-to-failure mapping  
**Consequences:** 
- Type-safe error handling
- Clear separation of concerns
- User-friendly error messages
- Easy to test and maintain

---

## Error Handling Flow

The error handling follows a three-layer mapping strategy:

```
Network Layer (DioException)
    ↓
Domain Layer (AppException)
    ↓
Presentation Layer (Failure)
    ↓
UI (User-friendly error message)
```

### 1. Network Layer → Domain Layer

**Mapper:** `DioExceptionMapper`  
**Location:** `lib/core/errors/dio_exception_mapper.dart`

Maps `DioException` types to domain-level `AppException` types:

- `DioExceptionType.connectionTimeout` → `NetworkException`
- `DioExceptionType.sendTimeout` → `NetworkException`
- `DioExceptionType.receiveTimeout` → `NetworkException`
- `DioExceptionType.badResponse` (4xx) → `ServerException`
- `DioExceptionType.badResponse` (5xx) → `ServerException`
- `DioExceptionType.cancel` → `NetworkException`
- `DioExceptionType.connectionError` → `NetworkException`
- `DioExceptionType.badCertificate` → `NetworkException`
- `DioExceptionType.unknown` → `UnknownException`

**Usage:**
```dart
try {
  final response = await dio.get('/api/endpoint');
} on DioException catch (e) {
  throw DioExceptionMapper.map(e);
}
```

### 2. Domain Layer → Presentation Layer

**Mapper:** `ExceptionToFailureMapper`  
**Location:** `lib/core/errors/exception_to_failure_mapper.dart`

Maps `AppException` types to typed `Failure` objects:

- `ServerException` → `ServerFailure`
- `NetworkException` → `NetworkFailure`
- `CacheException` → `CacheFailure`
- `AuthException` → `AuthFailure`
- `ValidationException` → `ValidationFailure`
- `PermissionException` → `PermissionFailure`
- `UnknownException` → `UnknownFailure`

**Usage:**
```dart
try {
  // operation
} on AppException catch (e) {
  return ResultFailure(ExceptionToFailureMapper.map(e));
}
```

### 3. Presentation Layer → UI

**Location:** `lib/features/auth/presentation/providers/auth_provider.dart`

Failures are displayed to users via `AuthState.error`:

```dart
result.when(
  success: (user) {
    state = state.copyWith(user: user, error: null);
  },
  failureCallback: (failure) {
    state = state.copyWith(error: failure.message);
  },
);
```

---

## Exception Types

### AppException (Base)

**Location:** `lib/core/errors/exceptions.dart`

Base class for all domain exceptions. Contains:
- `message`: Human-readable error message
- `code`: Optional error code for programmatic handling

**Subtypes:**
- `ServerException` - API/server errors (4xx, 5xx)
- `NetworkException` - Network connectivity issues
- `CacheException` - Local storage errors
- `AuthException` - Authentication/authorization errors
- `ValidationException` - Input validation errors
- `PermissionException` - Permission denied errors
- `UnknownException` - Unclassified errors

---

## Failure Types

### Failure (Base)

**Location:** `lib/core/errors/failures.dart`

Base class for all typed failures. Contains:
- `message`: User-friendly error message
- `code`: Optional error code

**Subtypes:**
- `ServerFailure` - API/server errors
- `NetworkFailure` - Network connectivity issues
- `CacheFailure` - Local storage errors
- `AuthFailure` - Authentication/authorization errors
- `ValidationFailure` - Input validation errors
- `PermissionFailure` - Permission denied errors
- `UnknownFailure` - Unclassified errors

---

## Mapping Rules

### DioException → AppException

| DioException Type | AppException Type | Notes |
|-------------------|-------------------|-------|
| `connectionTimeout` | `NetworkException` | Connection timed out |
| `sendTimeout` | `NetworkException` | Send operation timed out |
| `receiveTimeout` | `NetworkException` | Receive operation timed out |
| `badResponse` (400-499) | `ServerException` | Client error (4xx) |
| `badResponse` (500-599) | `ServerException` | Server error (5xx) |
| `cancel` | `NetworkException` | Request cancelled |
| `connectionError` | `NetworkException` | Connection failed |
| `badCertificate` | `NetworkException` | SSL certificate error |
| `unknown` | `UnknownException` | Unknown error |

### AppException → Failure

| AppException Type | Failure Type | Notes |
|-------------------|--------------|-------|
| `ServerException` | `ServerFailure` | Preserves message and code |
| `NetworkException` | `NetworkFailure` | Preserves message and code |
| `CacheException` | `CacheFailure` | Preserves message and code |
| `AuthException` | `AuthFailure` | Preserves message and code |
| `ValidationException` | `ValidationFailure` | Preserves message and code |
| `PermissionException` | `PermissionFailure` | Preserves message and code |
| `UnknownException` | `UnknownFailure` | Preserves message and code |

---

## Usage Examples

### Example 1: Data Source Error Handling

```dart
// lib/features/auth/data/datasources/auth_remote_datasource.dart
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  @override
  Future<AuthResponseModel> login(String email, String password) async {
    try {
      final response = await apiClient.post(
        ApiEndpoints.login,
        data: {'email': email, 'password': password},
      );
      return AuthResponseModel.fromJson(response.data);
    } on DioException catch (e) {
      // DioExceptionMapper is called by ErrorInterceptor
      // If it's not caught, it will be mapped automatically
      rethrow;
    }
  }
}
```

### Example 2: Repository Error Handling

```dart
// lib/features/auth/data/repositories/auth_repository_impl.dart
@override
Future<Result<User>> login(String email, String password) async {
  try {
    final authResponse = await remoteDataSource.login(email, password);
    await localDataSource.cacheUser(authResponse.user);
    await localDataSource.cacheToken(authResponse.token);
    return Success(authResponse.user.toEntity());
  } on AppException catch (e) {
    return ResultFailure(ExceptionToFailureMapper.map(e));
  } on Exception catch (e) {
    // Fallback for any other exceptions
    return ResultFailure(ExceptionToFailureMapper.map(e));
  }
}
```

### Example 3: Presentation Layer Error Handling

```dart
// lib/features/auth/presentation/providers/auth_provider.dart
Future<void> login(String email, String password) async {
  // Clear previous error
  state = state.copyWith(isLoading: true, error: null);

  final loginUseCase = ref.read(loginUseCaseProvider);
  final result = await loginUseCase(email, password);

  result.when(
    success: (user) {
      // Clear error on success
      state = state.copyWith(
        user: user,
        isLoading: false,
        error: null,
      );
    },
    failureCallback: (failure) {
      // Display user-friendly error message
      state = state.copyWith(
        isLoading: false,
        error: failure.message,
      );
    },
  );
}
```

### Example 4: UI Error Display

```dart
// lib/features/auth/presentation/screens/login_screen.dart
@override
Widget build(BuildContext context) {
  final authState = ref.watch(authNotifierProvider);

  return Scaffold(
    body: Column(
      children: [
        // Form fields...
        
        // Display error if present
        if (authState.error != null)
          Text(
            authState.error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        
        // Submit button...
      ],
    ),
  );
}
```

---

## Best Practices

### 1. Always Use Typed Failures

✅ **Good:**
```dart
return ResultFailure(ServerFailure('Server error', code: '500'));
```

❌ **Bad:**
```dart
return ResultFailure(UnknownFailure('Error occurred'));
```

### 2. Preserve Error Codes

✅ **Good:**
```dart
ServerFailure(exception.message, code: exception.code)
```

❌ **Bad:**
```dart
ServerFailure(exception.message) // Lost error code
```

### 3. Make Error Messages User-Friendly

✅ **Good:**
```dart
NetworkFailure('Unable to connect. Please check your internet connection.')
```

❌ **Bad:**
```dart
NetworkFailure('DioExceptionType.connectionTimeout')
```

### 4. Clear Errors Before New Operations

✅ **Good:**
```dart
state = state.copyWith(isLoading: true, error: null);
```

❌ **Bad:**
```dart
state = state.copyWith(isLoading: true); // Old error persists
```

### 5. Handle All Exception Types

✅ **Good:**
```dart
try {
  // operation
} on AppException catch (e) {
  return ResultFailure(ExceptionToFailureMapper.map(e));
} on Exception catch (e) {
  return ResultFailure(ExceptionToFailureMapper.map(e));
}
```

❌ **Bad:**
```dart
try {
  // operation
} catch (e) {
  // Too generic, loses type information
}
```

---

## Error Interceptor

**Location:** `lib/core/network/interceptors/error_interceptor.dart`

The `ErrorInterceptor` automatically maps `DioException` to `AppException`:

```dart
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final appException = DioExceptionMapper.map(err);
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: appException,
      ),
    );
  }
}
```

This ensures all network errors are automatically converted to domain exceptions before reaching repositories.

---

## Testing Error Handling

### Testing Exception Mapping

```dart
// test/core/errors/dio_exception_mapper_test.dart
test('should map connection timeout to NetworkException', () {
  final dioException = DioException(
    requestOptions: RequestOptions(path: '/test'),
    type: DioExceptionType.connectionTimeout,
  );
  
  final result = DioExceptionMapper.map(dioException);
  
  expect(result, isA<NetworkException>());
  expect(result.message, contains('connection'));
});
```

### Testing Failure Mapping

```dart
// test/core/errors/exception_to_failure_mapper_test.dart
test('should map ServerException to ServerFailure', () {
  const exception = ServerException('Server error', code: '500');
  
  final failure = ExceptionToFailureMapper.map(exception);
  
  expect(failure, isA<ServerFailure>());
  expect(failure.message, 'Server error');
  expect(failure.code, '500');
});
```

### Testing Error Handling in Repositories

```dart
// test/features/auth/data/repositories/auth_repository_impl_test.dart
test('should return ServerFailure when remote data source throws ServerException', () async {
  when(() => mockRemoteDataSource.login(any(), any()))
      .thenThrow(const ServerException('Server error'));
  
  final result = await repository.login('test@test.com', 'password');
  
  expect(result.isFailure, true);
  expect(result.failureOrNull, isA<ServerFailure>());
});
```

---

## Error Codes

Error codes are optional but recommended for programmatic error handling:

### Common Error Codes

- `'400'` - Bad Request
- `'401'` - Unauthorized
- `'403'` - Forbidden
- `'404'` - Not Found
- `'500'` - Internal Server Error
- `'NETWORK_ERROR'` - Network connectivity issue
- `'CACHE_ERROR'` - Local storage error
- `'REFRESH_TOKEN_EXPIRED'` - Refresh token expired
- `'VALIDATION_ERROR'` - Input validation failed

### Using Error Codes

```dart
result.when(
  success: (user) => handleSuccess(user),
  failureCallback: (failure) {
    if (failure.code == '401') {
      // Handle unauthorized
      navigateToLogin();
    } else if (failure.code == 'REFRESH_TOKEN_EXPIRED') {
      // Handle token expiry
      logout();
    } else {
      // Handle other errors
      showError(failure.message);
    }
  },
);
```

---

## Summary

1. **Network errors** are automatically mapped to domain exceptions by `ErrorInterceptor`
2. **Domain exceptions** are mapped to typed failures in repositories
3. **Typed failures** are displayed to users via state management
4. **Error codes** are preserved for programmatic handling
5. **Error messages** are user-friendly and contextual

This strategy ensures:
- ✅ Type-safe error handling
- ✅ Clear separation of concerns
- ✅ User-friendly error messages
- ✅ Easy to test and maintain
- ✅ Consistent error handling across the app

---

## References

- [Dio Error Handling](https://pub.dev/packages/dio#handling-errors)
- [Result Type Pattern](https://dart.dev/guides/libraries/creating-packages)
- [Clean Architecture Error Handling](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)

