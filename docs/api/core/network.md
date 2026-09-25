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

### Where dio is allowed to appear

Since koniz-dev/flutter-starter#176 the request surface of `ApiClient` is typed
entirely on `lib/core/contracts/network_contracts.dart`: every verb returns
`NetworkResponse<dynamic>` and takes `Map<String, String>? headers` rather than
dio's `Options`. A data source can therefore hold an `ApiClient` without
importing `package:dio`, which is what makes `INetworkClient` genuinely
swappable - before #176 the sample auth data source was typed on
`dio.Response` and swapping the transport meant editing every data source.

The rule the tree follows, checkable with one command:

```bash
grep -rn "package:dio" lib | grep -v "^lib/core/network/"
# -> lib/core/errors/dio_exception_mapper.dart:1
```

`package:dio` may be imported only by code whose job *is* dio - everything under
`lib/core/network/` (the adapter and the interceptors, which implement dio's own
`Interceptor` API) plus the one designated mapper,
`lib/core/errors/dio_exception_mapper.dart`, which exists solely to translate
`DioException` into a domain exception. Rewriting that mapper without the import
is impossible; it would only move the import somewhere less obvious. Nothing
under `lib/features/` may import it.

`ApiClient.dio` is **kept** as a deliberate escape hatch for transport-level
work - swapping `httpClientAdapter` in a test, inspecting `interceptors`,
reading `BaseOptions`. It is no longer on any request path, so using it is an
explicit opt-out of the contract rather than something an ordinary `post()`
forces on the caller. Typing a data source on what it returns puts
`package:dio` back in the feature layer, which is the leak #176 closed.

### Constructor

<!-- signature: lib/core/network/api_client.dart ApiClient -->
```dart
ApiClient({
  required StorageService storageService,
  required SecureStorageService secureStorageService,
  required AuthInterceptor authInterceptor,
  LoggingService? loggingService,
  IPerformanceService? performanceService,
  SslPinning? sslPinning,
});
```

| Parameter | Required | Effect |
|---|---|---|
| `storageService` | yes | Non-sensitive storage; backs `CacheInterceptor` |
| `secureStorageService` | yes | Secure storage for authentication tokens |
| `authInterceptor` | yes | Token injection and 401 refresh |
| `loggingService` | no | **Passing it is what installs `ApiLoggingInterceptor`.** Omit it and there is no HTTP logging at all, whatever `ENABLE_HTTP_LOGGING` says |
| `performanceService` | no | **Passing it is what installs `PerformanceInterceptor`.** Omit it and no HTTP trace is ever started |
| `sslPinning` | no | Certificate pinning policy; defaults to `SslPinning.fromConfig()`, which reads `ENABLE_SSL_PINNING` and `API_SSL_FINGERPRINTS` |

The two optional services are installed conditionally in `ApiClient._createDio`
(`if (loggingService != null)` / `if (performanceService != null)`), so their
interceptors are absent from the chain rather than inert when they are omitted.

`apiClientProvider` passes both, so the default app has both interceptors
installed. They are still quiet by default at *runtime* for separate reasons:
`ApiLoggingInterceptor` returns early unless `AppConfig.enableHttpLogging` is
true, and `performanceServiceProvider` yields a no-op service until it is
overridden. Hand-assembling an `ApiClient` without those two arguments is a
different thing from leaving the flags off - it removes the interceptors.

The directive above the code block is not decoration: `tool/check_docs.dart`
compares that parameter list against
[`lib/core/network/api_client.dart`](../../../lib/core/network/api_client.dart)
and fails the Docs check if they differ. See
[Keeping these signatures honest](#keeping-these-signatures-honest).

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
/// - [headers]: Optional per-request headers
/// 
/// Returns:
/// - [Future<NetworkResponse<dynamic>>]: transport-agnostic response
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
Future<NetworkResponse<dynamic>> get(
  String path, {
  Map<String, dynamic>? queryParameters,
  Map<String, String>? headers,
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
/// - [headers]: Optional per-request headers
/// 
/// Returns:
/// - [Future<NetworkResponse<dynamic>>]: transport-agnostic response
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
Future<NetworkResponse<dynamic>> post(
  String path, {
  dynamic data,
  Map<String, dynamic>? queryParameters,
  Map<String, String>? headers,
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
/// - [headers]: Optional per-request headers
/// 
/// Returns:
/// - [Future<NetworkResponse<dynamic>>]: transport-agnostic response
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
Future<NetworkResponse<dynamic>> put(
  String path, {
  dynamic data,
  Map<String, dynamic>? queryParameters,
  Map<String, String>? headers,
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
/// - [headers]: Optional per-request headers
/// 
/// Returns:
/// - [Future<NetworkResponse<dynamic>>]: transport-agnostic response
/// 
/// Throws:
/// - [ServerException]: If server returns error status code
/// - [NetworkException]: If network connection fails
/// 
/// Example:
/// ```dart
/// await apiClient.delete('/users/123');
/// ```
Future<NetworkResponse<dynamic>> delete(
  String path, {
  dynamic data,
  Map<String, dynamic>? queryParameters,
  Map<String, String>? headers,
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

<!-- signature: lib/core/network/interceptors/auth_interceptor.dart AuthInterceptor -->
```dart
AuthInterceptor({
  ITokenStore? tokenStore,
  SecureStorageService? secureStorageService,
  required Future<Result<String>> Function() refreshToken,
  Dio Function()? retryDioFactory,
  IKeyValueStore? keyValueStore,
  ISessionTerminationSink? sessionSink,
  SessionGeneration? sessionGeneration,
});
```

| Parameter | Required | Notes |
|---|---|---|
| `tokenStore` | no | Where tokens are read and written |
| `secureStorageService` | no | Legacy alternative to `tokenStore`; wrapped in a `SecureTokenStore` |
| `refreshToken` | **yes** | Callback that mints a new access token |
| `retryDioFactory` | no | Builds the client used to replay the original request; see [retryDioFactory](#retrydiofactory) |
| `keyValueStore` | no | Non-sensitive store holding the cached user blob, cleared on forced logout |
| `sessionSink` | no | Told the session is over, so the running app drops in-memory session state |
| `sessionGeneration` | no | Marks which sign-in a credential write belongs to; see [Refreshing across a logout](#refreshing-across-a-logout). Defaults to a private instance |

**Exactly one of `tokenStore` or `secureStorageService` must be supplied.**
Both are individually optional in the signature, but passing neither throws
`ArgumentError('Either tokenStore or secureStorageService must be provided.')`
from the initializer list. `tokenStore` wins when both are given.

**`refreshToken` is the only required parameter, and it is a callback, not a
repository.** That is deliberate: `AuthRepository` depends on `ApiClient`, which
depends on this interceptor, so holding a repository here would close a
dependency cycle at bootstrap. `authInterceptorProvider` passes
`() => ref.read(authRepositoryProvider).refreshToken()`, resolving the
repository lazily at call time.

Note that `always_put_required_named_parameters_first` is suppressed at the top
of the source file, so the required parameter sits third. The order above is the
source order.

### Post-construction wiring

Two dependencies are attached by `ApiClient._createDio` after construction,
because neither exists yet when `authInterceptorProvider` builds the
interceptor:

| Call | Supplies | Effect when never called |
|---|---|---|
| `attachTransport(dio)` | The host client | The 401 replay builds its own Dio and pins it from `SslPinning.fromConfig()` instead of borrowing the host adapter |
| `attachResponseCache(cache)` | The `CacheInterceptor` | Forced logout skips the cache-clearing step |

Also public: `tokenStore` (read by `CacheInterceptor` for its credential
check), `retryDio()` (the lazily built replay client) and `dispose()` (closes
that client's connection pool; wired to provider disposal).

### retryDioFactory

`retryDioFactory` builds the client that replays the original request after a
successful token refresh. **Production passes nothing:**
`authInterceptorProvider` omits it, so `retryDio()` falls back to `_buildRetryDio()`, which creates one
client, borrows the host transport through `SharedTransportAdapter` (so the
replay goes through the same pinned adapter), and reuses it. Tests inject a
factory to aim the replay at a fake `HttpClientAdapter`.

It is a **supported extension point**, not a private hook, and it carries one
sharp edge:

> **Never return the assembled `ApiClient`'s own `Dio` from this factory.** The
> replay would re-enter the full interceptor chain - including this
> `AuthInterceptor` - so a replay that 401s again recurses through the refresh
> path instead of failing. The default implementation borrows the host
> *transport* only, never its interceptors, for exactly this reason. Return a
> fresh `Dio` whose adapter you control.

Replacing the factory also discards the transport-sharing above, so a custom
client is only pinned if you pin it yourself.

**Why documented rather than annotated `@visibleForTesting`.** The annotation
does work on a named parameter - a cross-library production call site draws
`invalid_use_of_visible_for_testing_member`, verified under issue 89 and
recorded in `docs/verification/issue-89/visible-for-testing-probe.log`. It was
declined for two reasons. It would edit
`lib/core/network/interceptors/auth_interceptor.dart`, which is
`epic:core-network`, not `epic:docs`; and it would forbid the parameter to
forks that legitimately want to control the replay client, which is a policy
change rather than a documentation fix. If the parameter should instead be
test-only, that is a `epic:core-network` decision and belongs in its own issue.

### Features

- Automatically adds `Authorization: Bearer <token>` header to requests
- Handles 401 Unauthorized responses by refreshing tokens
- Queues pending requests during token refresh
- Retries failed requests with new token
- Excludes auth endpoints (login, register, refresh, logout) from token refresh

### Behavior

**On Request:**
- Reads the access token from the `ITokenStore`
- Adds `Authorization: Bearer <token>` header when the token is non-empty

**On 401 Error** (`_handle401Error`, in order):

1. Excluded endpoints (see the list below) are passed straight through - no
   refresh is attempted.
2. A request already carrying `X-Retry-Count: 1` has been replayed once
   already: the session is logged out and this request is rejected.
3. If a refresh is already in flight, the request is queued in
   `_pendingRequests` and this handler returns.
4. Otherwise the `refreshToken` callback runs.
   - **Success:** the new token is written to the token store, the original
     request is replayed through `retryDio()` with
     `Authorization: Bearer <new token>` and `X-Retry-Count: 1`, and the
     handler resolves with the replayed response. Unless the session ended
     while the refresh was in flight - see
     [Refreshing across a logout](#refreshing-across-a-logout), which is
     checked before any of that happens.
   - **Failure** (a `Result` failure, a null token, or anything thrown -
     `Error` as well as `Exception`): the session is logged out and the
     handler is rejected.
5. **Every queued handler is then completed, on both paths.** `finally` clears
   the in-flight flag first, then drains `_pendingRequests`: with a fresh token
   each queued request is replayed and resolved (rejected if its replay
   fails), and without one each is rejected with its own original error.

Point 5 is the part this document used to get wrong. It said "rejects request",
singular, and until the drain was fixed that was accurate - a concurrent 401
whose refresh failed left its caller awaiting a future that was never
completed. `_drainPendingRequests` now rejects every queued handler explicitly,
and clearing `_isRefreshing` before the drain means a 401 arriving during the
drain starts a fresh refresh rather than queueing behind a finished one.

**Forced logout (the 401 path):**

When the refresh fails, there is no refresh token, or the retry is already exhausted, `AuthInterceptor` logs the session out itself. That teardown clears the **same three persisted things** `AuthRepositoryImpl.logout()` clears - the tokens, the cached user blob, and the HTTP response cache (see [CacheInterceptor](#cacheinterceptor)) - so a session that ends by token expiry leaves the device in the same state as one the user ended by tapping "log out". A fourth step then notifies `sessionSink`, so the running app drops the in-memory session too rather than presenting a signed-in UI backed by storage that is now empty.

The cache reference is supplied by `ApiClient._createDio` through `authInterceptor.attachResponseCache(...)`, because the cache is a `CacheInterceptor` the client builds itself and so does not exist when `authInterceptorProvider` constructs the interceptor. It is optional: an interceptor nobody attaches a cache to simply skips that step, exactly as `httpCache` is optional on `AuthRepositoryImpl`.

A fourth step then tells the **running app**. Clearing storage only fixes the next launch; the session this launch is rendering lives in memory, in `AuthNotifier`. The interceptor reaches it through `ISessionTerminationSink` (`lib/core/contracts/state_boundary_contracts.dart`), implemented by `RiverpodSessionTerminationSink` in the auth feature and handed down by `authInterceptorProvider`, so nothing in `lib/core/network` imports the feature that owns the session. The sink resolves the notifier lazily, at the moment a session is terminated rather than at construction, which is what keeps the edge notifier -> use case -> repository -> remote data source -> `ApiClient` -> interceptor from closing into a cycle. It is optional for the same reason the cache is.

The app is **not** navigated anywhere from here. The interceptor only drops the session; the existing guard in `lib/core/routing/app_router.dart` reacts to the state change through its `refreshListenable` and performs the redirect to `/login`. Keeping navigation in one place is what lets the guard's deep-link round trip and its "no `/login` flash while the session restores" behaviour keep working.

Every step of the teardown is independently guarded and best-effort, and no step is nested inside another's null check: a dependency that was never wired skips only its own step. A step that throws must never leave the 401 handler uncompleted, so the error still surfaces to the caller either way. `sessionSink.onSessionTerminated()` swallowing its errors is load-bearing rather than lazy - a background request can 401 after the app's `ProviderContainer` is gone, and resolving a disposed provider throws. In particular, notifying the sink is wrapped: a background request can 401 after the app's `ProviderContainer` is gone, and resolving a provider from a disposed container throws.

**Excluded Endpoints:**

Taken from `ApiEndpoints`, and matched with `path.contains(endpoint)` against
the request path:

- `/auth/login` (`ApiEndpoints.login`)
- `/auth/register` (`ApiEndpoints.register`)
- `/auth/refresh` (`ApiEndpoints.refreshToken`)
- `/auth/logout` (`ApiEndpoints.logout`)

### Refreshing across a logout

A refresh is a read-modify-write that spans a full network round trip, and the
thing it writes back - the access and refresh tokens - is shared mutable state.
A user tapping "log out" while a background 401 is refreshing is ordinary use,
not a microsecond race, and until #169 nothing in the refresh path noticed: the
response came back after the teardown and re-persisted a complete, unexpired
credential pair onto a device that was signed out on screen. Three unconditional
writes sat behind that one round trip - `cacheToken` and `cacheRefreshToken`
inside `AuthRepositoryImpl.refreshToken()`, and `setAccessToken` here.

`SessionGeneration` (`lib/core/session/session_generation.dart`) is what makes
those writes conditional. It is a monotonically increasing counter, shared
between this interceptor and `AuthRepositoryImpl` through
`sessionGenerationProvider`:

- Every transition that replaces or removes the credential set calls
  `invalidate()` **before** its own `await`s: `AuthRepositoryImpl.logout()`,
  `login()` and `register()`, and `AuthInterceptor._logoutUser()`.
- Both refresh paths read `current` before the round trip and check
  `isCurrent(...)` immediately before persisting. A generation that has been
  left behind can never become current again, so a stale refresh writes
  nothing.

A counter rather than a `terminated` flag, because a boolean answers "is there
a session right now", which is the wrong question: signing back in while an old
refresh is in flight clears the flag again and the stale response lands on the
*new* user's tokens. That is also why a stale refresh **skips** its writes
rather than clearing the store - clearing would destroy the credentials of a
session that started during the refresh.

Queued requests are **rejected, not replayed**, once the generation they were
queued under is stale. Replaying would put `Authorization: Bearer ...` on the
wire for a user who has signed out; the check sits inside the drain loop, so a
logout landing part-way through stops the remaining replays too. Rejection
still completes every handler, so the guarantee from point 5 above is
unaffected.

The guard does not wedge anything. Each refresh reads the generation afresh, so
the first 401 after a successful `login()` refreshes normally.

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

**Scope:** Dio traffic only. This is the *only* automatic retry in the
template - Riverpod's provider-level auto-retry is disabled process-wide, so a
provider doing non-Dio I/O gets no retry from anywhere. See
[Riverpod retry policy](../../architecture/riverpod-retry-policy.md).

### Constructor

<!-- signature: lib/core/network/interceptors/retry_interceptor.dart RetryInterceptor -->
```dart
RetryInterceptor({
  required this.dio,
  this.loggingService,
  this.maxRetries = 3,
  this.initialExecutionDelay = const Duration(seconds: 1),
});
```

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
  headers: {'Idempotency-Key': orderUuid},
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

The write time is stored through `DateFormatter.formatIso8601`, so it is UTC and always carries the `Z` designator, and read back through `DateFormatter.parseIso8601`. Age is then the distance between two absolute instants and does not move when the device's UTC offset does - before koniz-dev/flutter-starter#188 it was a bare local `DateTime.now().toIso8601String()`, which writes no designator at all, so a flight or a DST transition aged every earlier entry out by the offset. An offset-less entry already on the device is still read as local wall clock, exactly as before, and is rewritten in the new form on the first refetch.

Do not relax the credential check without first moving the store to `SecureStorageService`.

### Lifetime

- `maxAge` (default 1 hour): entries newer than this are served directly.
- `maxStale` (default 7 days): older entries are still served, then removed once past this.
- A stored timestamp that does not parse, or whose calendar date is out of range such as `2024-02-30`, has no age: the entry is removed and the read reported as a miss rather than aged on a guess. The whole cost is one network request.
- `CacheInterceptor.clearCache()` walks `http_cache_index` and removes every body, every timestamp and the index itself.

`clearCache()` is reachable as `apiClient.responseCache` (typed `IHttpResponseCache`, so callers do not depend on dio). **Both** logout paths call it, so cached bodies do not outlive a session whichever way the session ends:

- explicit logout - `AuthRepositoryImpl.logout()`, in the same unconditional teardown block that clears the tokens and the cached user;
- forced logout - `AuthInterceptor`, on a 401 whose refresh fails (see [AuthInterceptor](#authinterceptor)).

### Constructor

<!-- signature: lib/core/network/interceptors/cache_interceptor.dart CacheInterceptor -->
```dart
CacheInterceptor({
  required StorageService storageService,
  CacheConfig? cacheConfig,
  ITokenStore? tokenStore,
});
```

<!-- signature: lib/core/network/interceptors/cache_interceptor.dart CacheConfig -->
```dart
const CacheConfig({
  this.maxAge = const Duration(hours: 1),
  this.maxStale = const Duration(days: 7),
  this.enableCache = true,
});
```

`cacheConfig` defaults to `const CacheConfig()`, i.e. the defaults above.

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

## Keeping these signatures honest

Every `dart` block above that declares a constructor is preceded by an HTML
comment of the form:

```text
<!-- signature: lib/core/network/api_client.dart ApiClient -->
```

`tool/check_docs.dart` reads those directives (implementation in
`tool/doc_signatures.dart`), extracts the named-parameter list from the block
and from the constructor of that name in that source file, and fails when they
differ - parameter for parameter, in order, including types, `required` markers
and default values.

**Both drift directions are covered, by two different gates**, because neither
gate alone sees both:

| Change | Gate that catches it |
|---|---|
| Someone edits this file and mistypes a parameter | Docs check (`docs-check.yml`) - fires on `**/*.md` |
| Someone adds a parameter in `lib/core/network/` and forgets this file | Quality gate (`ci.yml`) - `test/docs/doc_signatures_test.dart` runs the same comparison under `flutter test` |

That split matters. `ci.yml` reports on every PR but **skips its analyze and
test steps when the diff is only markdown**, and `docs-check.yml` only fires on
markdown, so a docs-side typo is seen by exactly one of them and a code-side
addition by exactly the other. Wiring this check into a single gate would leave
it blind to one direction - and the code side is the direction that produced
koniz-dev/flutter-starter#89: five commits changing constructors in
`lib/core/network/` with no markdown in the diff.

Covered here: `ApiClient`, `AuthInterceptor`, `RetryInterceptor`,
`CacheInterceptor`, `CacheConfig`.

What it does **not** cover, stated plainly:

- **Method signatures.** The `get`/`post`/`put`/`delete` blocks above are
  checked by hand only.
- **Prose.** Nothing mechanically ties the behaviour descriptions to the code;
  a wrong sentence about the 401 path still needs a reader.
- **One-line constructors.** The parser only matches a constructor whose
  parameter list opens with `Name({` at the end of a line, which is what
  `dart format` produces for multi-line lists. `ApiLoggingInterceptor` and
  `PerformanceInterceptor` each declare a single parameter on one line and are
  therefore not coverable - a directive pointed at one fails loudly rather than
  passing silently.
- **Semantics.** A parameter can match textually and still be documented
  wrongly in the table beside it.

To add coverage for a new constructor, put the directive above its fenced
block. No registration list to update.

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

### Custom Request Headers

```dart
final response = await apiClient.get(
  '/users',
  headers: {'Custom-Header': 'value'},
);
```

---

## Related APIs

- [Storage](storage.md) - Storage services used by interceptors
- [Errors](errors.md) - Exception types thrown by ApiClient
- [Configuration](../../guides/configuration.md) - AppConfig for base URL and timeouts


