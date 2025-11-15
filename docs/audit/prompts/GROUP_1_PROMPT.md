# Group 1: Error Handling Foundation - Self-Contained Implementation Prompt

**Last Updated:** November 15, 2025

## Context

I need to implement a complete error handling system for my Flutter Clean Architecture project. Currently, `DioException` errors from network requests are not properly converted to domain exceptions, and exceptions are not mapped to typed failures. This breaks the error handling flow throughout the application.

## Current State

### Problems:
1. **DioException never converted** - Network errors from Dio bubble up as generic exceptions
2. **No exception-to-failure mapping** - Repositories return generic `ResultFailure` instead of typed failures
3. **No error interceptor** - Each data source must handle conversion individually
4. **Inconsistent error handling** - Remote data sources have inconsistent error handling patterns
5. **Result type doesn't support typed failures** - `ResultFailure` is generic, can't distinguish error types

### Current Files:
- `lib/core/errors/exceptions.dart` - Defines domain exceptions (ServerException, NetworkException, CacheException, etc.)
- `lib/core/errors/failures.dart` - Defines typed failures (ServerFailure, NetworkFailure, CacheFailure, etc.)
- `lib/core/utils/result.dart` - Defines Result<T> with ResultFailure
- `lib/core/network/api_client.dart` - Dio wrapper that rethrows exceptions
- `lib/core/network/interceptors/auth_interceptor.dart` - Auth interceptor
- `lib/core/network/interceptors/logging_interceptor.dart` - Logging interceptor
- `lib/features/auth/data/datasources/auth_remote_datasource.dart` - Wraps all errors in ServerException
- `lib/features/auth/data/repositories/auth_repository_impl.dart` - Returns ResultFailure instead of typed failures

## Requirements

### 1. Create DioExceptionMapper
**File:** `lib/core/errors/dio_exception_mapper.dart`

Convert `DioException` to appropriate domain exceptions:
- `DioExceptionType.connectionTimeout` → `NetworkException`
- `DioExceptionType.sendTimeout` → `NetworkException`
- `DioExceptionType.receiveTimeout` → `NetworkException`
- `DioExceptionType.badResponse` → `ServerException` (with statusCode)
- `DioExceptionType.cancel` → `NetworkException`
- `DioExceptionType.connectionError` → `NetworkException`
- `DioExceptionType.badCertificate` → `NetworkException`
- `DioExceptionType.unknown` → `NetworkException`

Extract error messages and status codes from DioException.

### 2. Create ExceptionToFailureMapper
**File:** `lib/core/errors/exception_to_failure_mapper.dart`

Convert domain exceptions to typed failures:
- `ServerException` → `ServerFailure`
- `NetworkException` → `NetworkFailure`
- `CacheException` → `CacheFailure`
- `AuthException` → `AuthFailure`
- `ValidationException` → `ValidationFailure`
- Unknown exceptions → `UnknownFailure`

Preserve error messages and codes.

### 3. Create ErrorInterceptor
**File:** `lib/core/network/interceptors/error_interceptor.dart`

Dio interceptor that:
- Catches `DioException` in `onError`
- Converts to domain exceptions using `DioExceptionMapper`
- Re-throws as domain exceptions
- Should be added to Dio interceptors chain BEFORE other interceptors

### 4. Update Result Type
**File:** `lib/core/utils/result.dart`

Modify `ResultFailure` to accept `Failure` type:
```dart
final class ResultFailure<T> extends Result<T> {
  const ResultFailure(this.failure);
  final Failure failure;
}
```

Or create separate type:
```dart
final class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);
  final Failure failure;
}
```

Update extension methods to work with typed failures.

### 5. Update ApiClient
**File:** `lib/core/network/api_client.dart`

- Add `ErrorInterceptor` to interceptors chain
- Remove try-catch blocks that just rethrow (let interceptor handle)
- Or keep try-catch but convert DioException using mapper

### 6. Update AuthRemoteDataSource
**File:** `lib/features/auth/data/datasources/auth_remote_datasource.dart`

- Remove status code checks (Dio throws for non-2xx)
- Remove generic exception wrapping
- Let error interceptor handle DioException conversion
- Simplify error handling - just let exceptions bubble up

### 7. Update AuthRepositoryImpl
**File:** `lib/features/auth/data/repositories/auth_repository_impl.dart`

- Use `ExceptionToFailureMapper` to convert exceptions to typed failures
- Return typed failures: `ServerFailure`, `NetworkFailure`, `CacheFailure`
- Update all catch blocks to use mapper
- Change return type from `ResultFailure` to typed failure

## Implementation Details

### DioExceptionMapper Structure:
```dart
class DioExceptionMapper {
  static AppException map(DioException exception) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException(
          'Connection timeout: ${exception.message}',
        );
      case DioExceptionType.badResponse:
        return ServerException(
          _extractErrorMessage(exception),
          statusCode: exception.response?.statusCode,
        );
      // ... handle all types
    }
  }
  
  static String _extractErrorMessage(DioException exception) {
    // Extract from response.data or use default
  }
}
```

### ExceptionToFailureMapper Structure:
```dart
class ExceptionToFailureMapper {
  static Failure map(Exception exception) {
    return switch (exception) {
      ServerException(:final message, :final code, :final statusCode) =>
        ServerFailure(message, code: code),
      NetworkException(:final message, :final code) =>
        NetworkFailure(message, code: code),
      CacheException(:final message, :final code) =>
        CacheFailure(message, code: code),
      AuthException(:final message, :final code) =>
        AuthFailure(message, code: code),
      ValidationException(:final message, :final code) =>
        ValidationFailure(message, code: code),
      _ => UnknownFailure('Unexpected error: $exception'),
    };
  }
}
```

### ErrorInterceptor Structure:
```dart
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final domainException = DioExceptionMapper.map(err);
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: domainException,
        type: err.type,
        response: err.response,
      ),
    );
  }
}
```

## Testing Requirements

1. **Unit tests for DioExceptionMapper**
   - Test all DioException types
   - Test error message extraction
   - Test status code preservation

2. **Unit tests for ExceptionToFailureMapper**
   - Test all exception types
   - Test message and code preservation
   - Test unknown exception handling

3. **Integration test for error flow**
   - Test network error → exception → failure → UI
   - Test server error → exception → failure → UI
   - Test cache error → exception → failure → UI

4. **Test error interceptor**
   - Test DioException conversion
   - Test interceptor chain order

## Success Criteria

- ✅ All DioExceptions converted to domain exceptions
- ✅ All exceptions mapped to typed failures
- ✅ Error interceptor handles conversion automatically
- ✅ Repositories return typed failures
- ✅ UI can distinguish error types
- ✅ All tests pass
- ✅ No generic exception wrapping
- ✅ Error messages preserved and meaningful

## Files to Create

1. `lib/core/errors/dio_exception_mapper.dart`
2. `lib/core/errors/exception_to_failure_mapper.dart`
3. `lib/core/network/interceptors/error_interceptor.dart`

## Files to Modify

1. `lib/core/utils/result.dart` - Update ResultFailure type
2. `lib/core/network/api_client.dart` - Add error interceptor
3. `lib/features/auth/data/datasources/auth_remote_datasource.dart` - Simplify error handling
4. `lib/features/auth/data/repositories/auth_repository_impl.dart` - Use typed failures

## Dependencies

- `dio` package (already in pubspec.yaml)
- `lib/core/errors/exceptions.dart` (exists)
- `lib/core/errors/failures.dart` (exists)

## Notes

- Error interceptor should be first in chain (before auth, logging)
- Preserve all error information (message, code, statusCode)
- Make error messages user-friendly where possible
- Keep technical details for logging

---

## Common Mistakes to Avoid

### ❌ Don't wrap DioException in another DioException
- Convert to domain exceptions, don't wrap
- Example: `throw DioException(...)` → `throw NetworkException(...)`

### ❌ Don't lose status code information
- Preserve `statusCode` from `DioException.response.statusCode`
- Pass to `ServerException` for proper error handling

### ❌ Don't make error messages too technical for UI
- Extract user-friendly messages from API responses
- Keep technical details for logging/debugging
- Example: "Connection timeout" not "DioExceptionType.connectionTimeout"

### ❌ Don't forget to handle null response data
- Check for `null` response bodies
- Provide fallback error messages
- Handle cases where `response.data` is not a Map

### ❌ Don't create circular dependencies
- Mappers should not depend on repositories
- Keep mappers pure utility functions
- No Riverpod dependencies in mappers

### ❌ Don't ignore error codes
- Preserve error codes from exceptions
- Pass codes to failures for programmatic handling
- Use codes for error categorization in UI

---

## Edge Cases to Handle

### 1. Null Response Body
- API returns null or empty response
- Extract error from status code or default message
- Example: 404 → "Resource not found"

### 2. Non-JSON Error Responses
- API returns HTML, plain text, or other formats
- Handle gracefully, extract what's possible
- Fallback to status code-based messages

### 3. Network Errors with Partial Data
- Connection drops mid-request
- Timeout after partial response
- Handle as network error, not server error

### 4. Cancelled Requests
- User cancels request
- App navigates away
- Don't show error to user, handle silently

### 5. Multiple Concurrent Errors
- Multiple requests fail simultaneously
- Ensure error interceptor is thread-safe
- Don't lose error information in concurrent scenarios

### 6. Error Response with Unexpected Structure
- API changes error response format
- Handle missing fields gracefully
- Provide sensible defaults

### 7. Timeout vs Connection Error
- Distinguish between timeout and connection refused
- Different user messages for each
- Timeout: "Request took too long"
- Connection: "Unable to connect to server"

### 8. 401 Unauthorized Edge Cases
- Token expired vs invalid credentials
- Don't convert to generic ServerException
- Let AuthInterceptor handle 401 specifically

---

## Expected Deliverables

Provide responses in this order:

### 1. Three New File Implementations (Complete Code)

**1.1. `lib/core/errors/dio_exception_mapper.dart`**
- Complete implementation with all DioException types
- Error message extraction logic
- Status code preservation
- Null-safe handling

**1.2. `lib/core/errors/exception_to_failure_mapper.dart`**
- Complete implementation for all exception types
- Message and code preservation
- Unknown exception handling
- Type-safe mapping

**1.3. `lib/core/network/interceptors/error_interceptor.dart`**
- Complete interceptor implementation
- Proper error conversion
- Integration with Dio interceptor chain

### 2. Updated Result Type (Complete Code)

**2.1. `lib/core/utils/result.dart`**
- Updated `ResultFailure` to accept `Failure` type
- Updated extension methods
- Pattern matching support
- Backward compatibility considerations

### 3. Updated ApiClient (Changes Only)

**3.1. `lib/core/network/api_client.dart`**
- Show only the changes (additions/modifications)
- Interceptor chain update
- Removed unnecessary try-catch blocks
- Clear diff/context

### 4. Updated RemoteDataSource (Changes Only)

**4.1. `lib/features/auth/data/datasources/auth_remote_datasource.dart`**
- Show only the changes
- Removed status code checks
- Removed generic exception wrapping
- Simplified error handling
- Clear before/after context

### 5. Updated Repository (Changes Only)

**5.1. `lib/features/auth/data/repositories/auth_repository_impl.dart`**
- Show only the changes
- Exception-to-failure mapping usage
- Updated catch blocks
- Typed failure returns
- Clear before/after context

### 6. Test File Examples (At Least 2)

**6.1. `test/core/errors/dio_exception_mapper_test.dart`**
- Unit tests for all DioException types
- Error message extraction tests
- Status code preservation tests
- Edge case tests

**6.2. `test/core/errors/exception_to_failure_mapper_test.dart`**
- Unit tests for all exception types
- Message/code preservation tests
- Unknown exception handling tests

**6.3. Optional: Integration Test**
- `test/features/auth/integration/auth_error_flow_test.dart`
- End-to-end error flow test
- Network error → exception → failure → UI

### 7. Migration Notes (Breaking Changes If Any)

**7.1. Breaking Changes**
- List any breaking changes to existing code
- API changes in Result type
- Changes to repository return types
- UI layer impact

**7.2. Migration Steps**
- Step-by-step migration guide
- Code examples for updating existing code
- Common patterns to update

**7.3. Backward Compatibility**
- What remains compatible
- Deprecation notices if any
- Timeline for full migration

---

## Implementation Checklist

Before submitting, verify:

- [ ] All DioException types handled
- [ ] All exception types mapped to failures
- [ ] Error interceptor added to Dio chain
- [ ] Result type updated with typed failures
- [ ] ApiClient uses error interceptor
- [ ] RemoteDataSource simplified
- [ ] Repository uses typed failures
- [ ] Edge cases handled
- [ ] Tests written and passing
- [ ] No breaking changes (or documented)
- [ ] Error messages user-friendly
- [ ] Status codes preserved
- [ ] Null safety handled
- [ ] Documentation updated

