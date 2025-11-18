# Network APIs

HTTP client and interceptors for making API requests.

## Overview

The network layer provides:
- `ApiClient` - HTTP client wrapper around Dio
- `AuthInterceptor` - Automatic token injection and refresh
- `ErrorInterceptor` - Exception conversion
- `LoggingInterceptor` - Request/response logging

---

## ApiClient

HTTP client for making API requests using Dio.

**Location:** `lib/core/network/api_client.dart`

### Constructor

```dart
/// Creates an instance of [ApiClient] with configured Dio instance
/// 
/// Parameters:
/// - [storageService]: Storage service for non-sensitive data
/// - [secureStorageService]: Secure storage service for authentication tokens
/// - [authInterceptor]: Auth interceptor for token management and refresh
ApiClient({
  required StorageService storageService,
  required SecureStorageService secureStorageService,
  required AuthInterceptor authInterceptor,
});
```

### Properties

- `Dio get dio` - Getter for the underlying Dio instance

### Methods

#### GET Request

```dart
/// GET request
/// 
/// Parameters:
/// - [path]: The endpoint path (relative to base URL)
/// - [queryParameters]: Optional query parameters
/// - [options]: Optional request options
/// 
/// Returns:
/// - [Future<Response<dynamic>>]: Dio response object
/// 
/// Throws:
/// - [ServerException]: If server returns error status code
/// - [NetworkException]: If network connection fails
/// 
/// Example:
/// ```dart
/// final response = await apiClient.get('/users', queryParameters: {'page': 1});
/// final data = response.data;
/// ```
Future<Response<dynamic>> get(
  String path, {
  Map<String, dynamic>? queryParameters,
  Options? options,
});
```

#### POST Request

```dart
/// POST request
/// 
/// Parameters:
/// - [path]: The endpoint path (relative to base URL)
/// - [data]: Optional request body data
/// - [queryParameters]: Optional query parameters
/// - [options]: Optional request options
/// 
/// Returns:
/// - [Future<Response<dynamic>>]: Dio response object
/// 
/// Throws:
/// - [ServerException]: If server returns error status code
/// - [NetworkException]: If network connection fails
/// 
/// Example:
/// ```dart
/// final response = await apiClient.post(
///   '/users',
///   data: {'name': 'John', 'email': 'john@example.com'},
/// );
/// ```
Future<Response<dynamic>> post(
  String path, {
  dynamic data,
  Map<String, dynamic>? queryParameters,
  Options? options,
});
```

#### PUT Request

```dart
/// PUT request
/// 
/// Parameters:
/// - [path]: The endpoint path (relative to base URL)
/// - [data]: Optional request body data
/// - [queryParameters]: Optional query parameters
/// - [options]: Optional request options
/// 
/// Returns:
/// - [Future<Response<dynamic>>]: Dio response object
/// 
/// Throws:
/// - [ServerException]: If server returns error status code
/// - [NetworkException]: If network connection fails
/// 
/// Example:
/// ```dart
/// final response = await apiClient.put(
///   '/users/123',
///   data: {'name': 'Jane'},
/// );
/// ```
Future<Response<dynamic>> put(
  String path, {
  dynamic data,
  Map<String, dynamic>? queryParameters,
  Options? options,
});
```

#### DELETE Request

```dart
/// DELETE request
/// 
/// Parameters:
/// - [path]: The endpoint path (relative to base URL)
/// - [data]: Optional request body data
/// - [queryParameters]: Optional query parameters
/// - [options]: Optional request options
/// 
/// Returns:
/// - [Future<Response<dynamic>>]: Dio response object
/// 
/// Throws:
/// - [ServerException]: If server returns error status code
/// - [NetworkException]: If network connection fails
/// 
/// Example:
/// ```dart
/// await apiClient.delete('/users/123');
/// ```
Future<Response<dynamic>> delete(
  String path, {
  dynamic data,
  Map<String, dynamic>? queryParameters,
  Options? options,
});
```

### Configuration

The ApiClient is configured with:
- Base URL from `AppConfig.baseUrl`
- Timeouts from `AppConfig` (connect, receive, send)
- Interceptors: ErrorInterceptor, AuthInterceptor, LoggingInterceptor (if enabled)

---

## AuthInterceptor

Dio interceptor for adding authentication tokens to requests and handling automatic token refresh on 401 errors.

**Location:** `lib/core/network/interceptors/auth_interceptor.dart`

### Constructor

```dart
/// Creates an [AuthInterceptor] with the given dependencies
/// 
/// Parameters:
/// - [secureStorageService]: Secure storage service for retrieving and storing tokens
/// - [authRepository]: Auth repository for refreshing tokens
AuthInterceptor({
  required SecureStorageService secureStorageService,
  required AuthRepository authRepository,
});
```

### Features

- Automatically adds `Authorization: Bearer <token>` header to requests
- Handles 401 Unauthorized responses by refreshing tokens
- Queues pending requests during token refresh
- Retries failed requests with new token
- Excludes auth endpoints (login, register, refresh, logout) from token refresh

### Behavior

**On Request:**
- Retrieves token from secure storage
- Adds `Authorization: Bearer <token>` header if token exists

**On 401 Error:**
1. Checks if endpoint should be excluded (login, register, refresh, logout)
2. If refresh is in progress, queues the request
3. Attempts token refresh using `AuthRepository.refreshToken()`
4. On success: Updates token, retries original request, processes queued requests
5. On failure: Logs out user and rejects request

**Excluded Endpoints:**
- `/login`
- `/register`
- `/refresh-token`
- `/logout`

### Usage

The interceptor is automatically configured when using `apiClientProvider`. No manual setup required.

---

## ErrorInterceptor

Interceptor for converting DioException to domain exceptions.

**Location:** `lib/core/network/interceptors/error_interceptor.dart`

### Behavior

- Converts DioException to domain exceptions (`ServerException`, `NetworkException`, etc.)
- Should be added FIRST in the interceptor chain
- Allows domain exceptions to be extracted in catch blocks

### Exception Mapping

- 4xx/5xx status codes → `ServerException`
- Network errors (timeout, connection) → `NetworkException`
- Other errors → `UnknownException`

---

## LoggingInterceptor

Interceptor for logging HTTP requests and responses.

**Location:** `lib/core/network/interceptors/logging_interceptor.dart`

### Behavior

- Logs request method, path, headers, data, query parameters
- Logs response status code, data
- Logs error status code, message, error data
- Only logs in debug mode (`kDebugMode`)
- Enabled when `AppConfig.enableHttpLogging` is true

### Log Format

**Request:**
```
REQUEST[GET] => PATH: /users
Headers: {...}
Data: {...}
QueryParams: {...}
```

**Response:**
```
RESPONSE[200] => PATH: /users
Data: {...}
```

**Error:**
```
ERROR[404] => PATH: /users/123
Message: Not Found
Error Data: {...}
```

---

## Usage Examples

### Basic API Request

```dart
final apiClient = ref.read(apiClientProvider);

// GET request
final response = await apiClient.get('/users');
final users = response.data as List;

// POST request
final response = await apiClient.post(
  '/users',
  data: {'name': 'John', 'email': 'john@example.com'},
);

// PUT request
final response = await apiClient.put(
  '/users/123',
  data: {'name': 'Jane'},
);

// DELETE request
await apiClient.delete('/users/123');
```

### With Query Parameters

```dart
final response = await apiClient.get(
  '/users',
  queryParameters: {
    'page': 1,
    'limit': 10,
    'sort': 'name',
  },
);
```

### Error Handling

```dart
try {
  final response = await apiClient.get('/users');
  // Handle success
} on ServerException catch (e) {
  // Handle server error (4xx, 5xx)
  print('Server error: ${e.message}, Status: ${e.statusCode}');
} on NetworkException catch (e) {
  // Handle network error (no connection, timeout)
  print('Network error: ${e.message}');
} on Exception catch (e) {
  // Handle other errors
  print('Error: $e');
}
```

### Custom Request Options

```dart
final response = await apiClient.get(
  '/users',
  options: Options(
    headers: {'Custom-Header': 'value'},
    responseType: ResponseType.json,
  ),
);
```

---

## Related APIs

- [Storage](storage.md) - Storage services used by interceptors
- [Errors](errors.md) - Exception types thrown by ApiClient
- [Configuration](../../README.md#configuration) - AppConfig for base URL and timeouts

