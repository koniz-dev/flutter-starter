# Network APIs

HTTP client and interceptors for making API requests.

## Overview

The network layer provides:
- `ApiClient` - HTTP client wrapper around Dio
- `INetworkClient` - Transport-agnostic network contract
- `DioNetworkClient` - Adapter implementing `INetworkClient`
- `IGraphQLClient` - Optional GraphQL support template
- `IRealtimeClient` - Decoupled interface for WebSocket streams
- `AuthInterceptor` - Automatic token injection and refresh
- `ErrorInterceptor` - Exception conversion
- `RetryInterceptor` - Retries transient failures for safe methods only
- `CacheInterceptor` - Caches unauthenticated `GET` responses in plaintext `shared_preferences`; see [CacheInterceptor](#cacheinterceptor)
- `PerformanceInterceptor` - Optional HTTP timing (when performance service is wired)
- `ApiLoggingInterceptor` - Request/response logging via `LoggingService` when enabled

---

## ApiClient

HTTP client for making API requests using Dio.

**Location:** `lib/core/network/api_client.dart`

`ApiClient` delegates transport calls to `INetworkClient` (`DioNetworkClient`).
Feature code that needs the full interceptor stack (auth, retry, logging, etc.)
should inject `ApiClient` via `apiClientProvider` or the typed alias
`networkClientProvider` (same instance).

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
- `INetworkClient get networkClient` - Transport-agnostic view of the same client
- `IHttpResponseCache get responseCache` - The locally persisted response cache; call `clearCache()` on session teardown (see [CacheInterceptor](#cacheinterceptor))

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
- Interceptors (order matters; see `ApiClient._createDio`): optional `PerformanceInterceptor`, `CacheInterceptor` (its bypass decision is order-independent - see [CacheInterceptor](#cacheinterceptor)), `AuthInterceptor`, `RetryInterceptor` (safe methods only by default - see [RetryInterceptor](#retryinterceptor)), optional `ApiLoggingInterceptor` when a `LoggingService` is provided, then `ErrorInterceptor` **last**. dio runs `onRequest` and `onError` in registration order, and `ErrorInterceptor.onError` terminates the chain with `handler.reject(...)`, so anything registered after it never sees the error.

---

## Realtime Client

The project provides an abstract interface `IRealtimeClient` for handling persistent connection data like WebSockets without leaking package specifics to the domain layer.

**Location:** `lib/core/network/realtime/`

### Implementations
- `NoOpRealtimeClient`: A mocked dummy client injected by default to prevent connection errors where real-time is not needed.
- `RawWebSocketClientImpl`: Concrete class powered by the `web_socket_channel` package.

### Usage Example
```dart
final realtimeClient = ref.read(realtimeClientProvider);

// Connect
await realtimeClient.connect('wss://example.com/socket');

// Subscribe to stream
realtimeClient.stream.listen((data) {
  print('Received real-time event: $data');
});

// Send payload
realtimeClient.send({'type': 'ping'});

// Disconnect
realtimeClient.disconnect();
```

---

## GraphQL Client

The project provides an interface `IGraphQLClient` and a structured template for integrating GraphQL into your network layer when needed.

**Location:** `lib/core/network/graphql_client_template.dart`

### Setup

1. Run: `flutter pub add graphql_flutter`
2. Follow the setup instructions at the top of the file to uncomment the logic.

This integration is optional and is not wired in the default dependency graph.

### Interface

The template conforms to `IGraphQLClient`:

```dart
abstract class IGraphQLClient {
  /// Performs a GraphQL Query
  Future<dynamic> query(String document, {Map<String, dynamic>? variables});
  
  /// Performs a GraphQL Mutation
  Future<dynamic> mutate(String document, {Map<String, dynamic>? variables});
}
```

### Features

- **Auth Injection**: Demonstrates how to tie Auth repository tokens into GraphQL headers.
- **Link Concatenation**: Example for concatenating HttpLink with AuthLink for secure communication.
- **Error Handling**: Template for mapping GraphQL exceptions into domain exceptions.


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
- Must be added LAST in the interceptor chain: its `onError` terminates the chain with `handler.reject(...)`, and dio invokes error handlers in registration order
- Allows domain exceptions to be extracted in catch blocks

### Exception Mapping

- 4xx/5xx status codes → `ServerException`
- Network errors (timeout, connection) → `NetworkException`
- Everything else (cancel, bad certificate, unknown) → `NetworkException`, with a `code` such as `UNKNOWN_NETWORK_ERROR` (`lib/core/errors/dio_exception_mapper.dart:13-75`). There is no `UnknownException` type.

---

## RetryInterceptor

Replays transient failures with exponential backoff plus jitter.

**Location:** `lib/core/network/interceptors/retry_interceptor.dart`

### Defaults

| Setting | Default |
|---|---|
| Methods retried | `GET`, `HEAD`, `OPTIONS` only |
| Attempts | 1 original + `maxRetries` replays, `maxRetries = 3` |
| Backoff | `initialExecutionDelay` (1s) doubled per attempt, plus 0-500ms jitter, so roughly 1s, 2s, 4s |
| Error types retried | `connectionTimeout`, `sendTimeout`, `receiveTimeout`, `connectionError`, and any `badResponse` with a 5xx status |

`ApiClient._createDio` constructs the interceptor with these defaults.

### Which methods are retried, and why

Only the **safe** methods of RFC 9110 section 9.2.1 (`GET`, `HEAD`, `OPTIONS`)
are replayed automatically. They have no server-side effect, so an extra
attempt cannot duplicate work.

`POST`, `PUT`, `PATCH` and `DELETE` are **not** replayed by default. For those,
the only retried error type is `connectionTimeout` - the one `DioExceptionType`
that proves no request byte reached the server, because the socket never
finished connecting. Every other transient failure leaves open the possibility
that the server received and committed the request:

| Failure | Replayed for a non-safe method? | Why |
|---|---|---|
| `connectionTimeout` | yes | The connection was never established; nothing was sent |
| `connectionError` | no | A `SocketException` also covers a connection reset *after* the body was delivered |
| `sendTimeout` | no | The request may have been fully or partly delivered |
| `receiveTimeout` | no | The server has the request and may already have committed it |
| 5xx | no | A 502/504 from a proxy can follow a successful upstream write |

Note that `PUT` and `DELETE` are idempotent but not safe, and are therefore
excluded as well. Idempotency promises only that the server-side *state* is
unchanged by a repeat, not that the repeat is harmless: a replayed `DELETE`
answers 404 and a replayed `PUT` can clobber a write that landed in between.

### Opting a non-safe request in

Two equivalent per-request opt-ins, both **off by default**:

```dart
// 1. Idempotency-Key header - works through the ApiClient facade, which
//    forwards headers but not `extra`. Send the key your backend
//    de-duplicates on.
await apiClient.post(
  '/orders',
  data: {'amount': 1},
  options: Options(headers: {'Idempotency-Key': orderUuid}),
);

// 2. extra['retry'] - for code holding a raw Dio instance.
await apiClient.dio.post(
  '/orders',
  data: {'amount': 1},
  options: Options(extra: {'retry': true}),
);
```

The header match is case-insensitive and an empty value does not opt in.
`extra: {'retry': false}` is the mirror image and suppresses retry even for a
safe method.

An override decides only **whether** a request may be replayed. The error-type
table and `maxRetries` still apply, so an opted-in `POST` gets the same 1 + 3
attempts a `GET` does.

---

## CacheInterceptor

Caches HTTP response bodies in local storage so a repeat request can be served without a round trip.

**Location:** `lib/core/network/interceptors/cache_interceptor.dart`

### What is cached

Only responses that satisfy **all** of these:

- Method is `GET`.
- Status is exactly `200`.
- The request carries no `cache-control: no-cache` / `no-store`, and no `authorization` or `cookie` header the caller attached itself.
- **There is no session credential.** Before every cache read and every cache write, the interceptor asks the same `ITokenStore` that `AuthInterceptor` authenticates from whether an access token exists. If one does, the request neither reads from nor writes to the cache and goes straight to the network.

**Authenticated responses are therefore never cached, and a response cached while signed out is never replayed to a signed-in request.** A signed-in app gets no HTTP response caching at all - that is deliberate, and it is the reason the plaintext store below is acceptable.

The credential check reads the token store rather than sniffing the outgoing `Authorization` header. dio runs `onRequest` in registration order and `CacheInterceptor` is registered before `AuthInterceptor`, so on the request leg that header does not exist yet - a header sniff there is dead code. Asking the store makes the decision correct wherever the interceptor sits in the chain.

### Where it is stored

In `StorageService`, i.e. **`shared_preferences`** - `/data/data/<pkg>/shared_prefs/*.xml` on Android, the app's `NSUserDefaults` plist on iOS. That is **plaintext**: readable on a rooted or jailbroken device and included in unencrypted device backups. It is not `SecureStorageService`.

Keys are `http_cache_<uri>_<queryParameters>` for the body and `http_cache_timestamp_<body key>` for the write time, plus `http_cache_index`, a `StringList` of every body key currently written.

Do not relax the credential check without first moving the store to `SecureStorageService`.

### Lifetime

- `maxAge` (default 1 hour): entries newer than this are served directly.
- `maxStale` (default 7 days): older entries are still served, then removed once past this.
- `CacheInterceptor.clearCache()` walks `http_cache_index` and removes every body, every timestamp and the index itself.

`clearCache()` is reachable as `apiClient.responseCache` (typed `IHttpResponseCache`, so callers do not depend on dio) and `AuthRepositoryImpl.logout()` calls it, so cached bodies do not outlive a session.

### Configuration

```dart
CacheInterceptor(
  storageService: storageService,
  tokenStore: authInterceptor.tokenStore,
  cacheConfig: const CacheConfig(
    maxAge: Duration(minutes: 5),
    maxStale: Duration(hours: 12),
    enableCache: true,
  ),
);
```

`enableCache: false` disables the interceptor entirely. Omitting `tokenStore` leaves only the header check, which cannot see a credential `AuthInterceptor` has not written yet - production wiring in `ApiClient._createDio` always passes it.

---

## ApiLoggingInterceptor

Interceptor for logging HTTP traffic through **`LoggingService`** (not raw `debugPrint`).

**Location:** `lib/core/network/interceptors/api_logging_interceptor.dart`

### Behavior

- No-op when `AppConfig.enableHttpLogging` is false
- **Request:** logs method, path, base URL, sanitized headers, sanitized query parameters, sanitized body
- **Response:** logs status, path, sanitized headers/body (warning level for 4xx+)
- **Error:** logs Dio error type, path, method, status, sanitized bodies. This path became reachable in `8a73fd2`; before that `ErrorInterceptor` terminated the chain first, so a failed login never reached the logger

### What gets redacted, and how it is decided

Redaction is decided by **key name only, never by the shape of the value**. A
value-shape rule ("redact anything that looks like a JWT") would catch tokens
hiding under unexpected key names, but it also redacts legitimate base64
payloads, hashes and opaque ids, and it makes the redaction set impossible to
predict by reading the code. The cost of the key-name rule is real and is stated
here rather than hidden: **a secret carried under a key name that is not listed
below is still logged.** The lists in `api_logging_interceptor.dart` are the
security boundary; extend them when an API invents a new credential parameter.

Every redacted value is replaced with the single literal `***REDACTED***`.

**Key matching.** A key is normalized to lowercase with every non-alphanumeric
character dropped, so `access_token`, `accessToken` and `X-Access-Token` all
reduce to `accesstoken`. It is then matched:

| Rule | Entries | Example match |
|---|---|---|
| Normalized key *contains* the fragment | `password`, `passwd`, `passphrase`, `token`, `secret`, `apikey`, `credential`, `authorization`, `privatekey`, `creditcard`, `cardnumber`, `signature`, `pincode`, `otpcode` | `refresh_token`, `client_secret` |
| Normalized key *equals* the entry | `pin`, `otp`, `cvv`, `cvc`, `session`, `sessionid` | `pin`, but not `shipping` |

The exact-match list exists because these names are too short to use as
fragments: `pin` occurs inside `shipping`, `cvc` inside `cvcNote`.

**Headers** additionally carry an explicit roster - `authorization`,
`proxy-authorization`, `cookie`, `set-cookie`, `x-api-key`, `api-key`,
`x-auth-token`, `x-refresh-token`, `x-csrf-token` - matched case-insensitively.
Header names are a closed, standardised namespace, so an explicit list is
auditable; the key rule above is applied as a second pass so a non-standard
credential header is still caught. Case-insensitivity matters because dio stores
headers in a case-insensitive map that preserves the caller's original casing,
so the `Authorization` key written by `AuthInterceptor` is redacted just like a
lowercase `authorization`.

**Query parameters** go through exactly the same key rule as bodies. They used
to be logged raw while the body of the same request was sanitized, which leaked
password-reset tokens, `?access_token=` values and `?api_key=` credentials.

One named residual: an OAuth **`code`** query parameter is *not* redacted. It is
a credential, but `code` is also one of the most common non-secret field names
there is (error code, country code, coupon code), and matching it would gut the
diagnostic value of every error body. If your provider's flow makes that
trade-off wrong for you, add `code` to the exact-match list.

**Bodies** are an allow-list of shapes the interceptor can actually walk:

| Body | Logged as |
|---|---|
| `Map` / `List` | walked recursively, sensitive keys replaced |
| `String` that decodes to a JSON object or array | decoded, then walked recursively |
| `String` that is not JSON - form-encoded, plain text, HTML | `***REDACTED***` wholesale |
| `String` that decodes to a bare JSON scalar (`"<token>"`, `42`) | `***REDACTED***` wholesale |
| `null`, `num`, `bool` | as-is |
| Anything else - `FormData`, streams, byte buffers | `***REDACTED***` wholesale |

The wholesale cases are deliberate. A `String` body that fails to parse offers
no keys to judge, and a form-encoded login body
(`grant_type=password&password=hunter2`) is a credential carrier; logging it
verbatim because parsing failed was the defect reported in
koniz-dev/flutter-starter#78. The trade-off is that plain-text error bodies are
no longer readable in the log - the status code, path and method still are. The
same reasoning covers `FormData`: a multipart login form holds the password in
`FormData.fields`, which no key walk can reach.

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
- [Configuration](../../guides/configuration.md) - AppConfig for base URL and timeouts


