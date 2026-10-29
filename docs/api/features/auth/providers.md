# Auth Providers

Riverpod providers for authentication dependency injection.

## Overview

Authentication providers live in `lib/features/auth/di/auth_providers.dart`. Import that file directly - `lib/core/di/providers.dart` used to re-export it, and no longer does: core naming a feature was half of an import cycle, and the re-export was the other half.

`authInterceptorProvider` moved the other way, into `lib/core/di/providers.dart`, because `apiClientProvider` installs it. The two things it needs from this feature arrive as overrides:

```dart
/// Plugs this slice into the authentication seams core declares.
final List<Override> authModuleOverrides = <Override>[
  tokenRefresherProvider.overrideWith(
    (ref) => () => ref.read(authRepositoryProvider).refreshToken(),
  ),
  sessionTerminationSinkProvider.overrideWith(
    RiverpodSessionTerminationSink.new,
  ),
];
```

`createAppContainer()` in `lib/main.dart` applies them, so an app built the normal way needs no extra wiring. A **test** that builds its own `ProviderContainer` and drives a real 401 through `apiClientProvider` must pass `...authModuleOverrides` itself; without them the container still resolves every provider, it just cannot refresh a session or clear the in-memory one.

---

## Data Source Providers

### authLocalDataSourceProvider

Provider for `AuthLocalDataSource` instance.

```dart
/// Provider for [AuthLocalDataSource] instance
///
/// Uses [IKeyValueStore] for user payload and [ITokenStore] for secrets.
final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  final storageService = ref.watch(keyValueStoreProvider);
  final tokenStore = ref.watch(tokenStoreProvider);
  return AuthLocalDataSourceImpl(
    storageService: storageService,
    tokenStore: tokenStore,
  );
});
```

### authRemoteDataSourceProvider

Provider for `AuthRemoteDataSource` instance.

```dart
/// Provider for [AuthRemoteDataSource] instance
///
/// Uses ref.read to break circular dependency with apiClientProvider.
final Provider<AuthRemoteDataSource> authRemoteDataSourceProvider =
    Provider<AuthRemoteDataSource>((ref) {
      if (DemoAuth.enabled) return DemoAuthRemoteDataSource();
      final apiClient = ref.read(networkClientProvider);
      return AuthRemoteDataSourceImpl(apiClient);
    });
```

---

## Repository Provider

### authRepositoryProvider

Provider for `AuthRepository` instance.

```dart
/// Provider for [AuthRepository] instance
///
/// Coordinates between remote and local data sources.
final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((ref) {
      final remoteDataSource = ref.read<AuthRemoteDataSource>(
        authRemoteDataSourceProvider,
      );
      final localDataSource = ref.watch(authLocalDataSourceProvider);
      return AuthRepositoryImpl(
        remoteDataSource: remoteDataSource,
        localDataSource: localDataSource,
        // Same ApiClient instance the remote data source already resolved, so
        // this adds no new edge to the provider graph.
        httpCache: ref.read(networkClientProvider).responseCache,
        // The *same* instance `authInterceptorProvider` holds. Two of the
        // three credential writes behind one 401 refresh happen in this
        // repository and one in the interceptor; they only agree about which
        // session is live if they share this counter.
        sessionGeneration: ref.watch(sessionGenerationProvider),
      );
    });
```

An override of `authRepositoryProvider` - a different data source, say - must
pass `httpCache` and `sessionGeneration` as well. Both are optional, so an
override without them compiles, but logout then stops clearing the HTTP cache
and a 401 refresh can write credentials into a session that has ended.


---

## Use Case Providers

### loginUseCaseProvider

Provider for `LoginUseCase` instance.

```dart
/// Provider for [LoginUseCase] instance
/// 
/// This provider creates a singleton instance of [LoginUseCase]
/// that handles user login business logic.
final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  final repository = ref.watch<AuthRepository>(authRepositoryProvider);
  return LoginUseCase(repository);
});
```

### registerUseCaseProvider

Provider for `RegisterUseCase` instance.

```dart
/// Provider for [RegisterUseCase] instance
/// 
/// This provider creates a singleton instance of [RegisterUseCase]
/// that handles user registration business logic.
final registerUseCaseProvider = Provider<RegisterUseCase>((ref) {
  final repository = ref.watch<AuthRepository>(authRepositoryProvider);
  return RegisterUseCase(repository);
});
```

### logoutUseCaseProvider

Provider for `LogoutUseCase` instance.

```dart
/// Provider for [LogoutUseCase] instance
/// 
/// This provider creates a singleton instance of [LogoutUseCase]
/// that handles user logout business logic.
final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  final repository = ref.watch<AuthRepository>(authRepositoryProvider);
  return LogoutUseCase(repository);
});
```

### refreshTokenUseCaseProvider

Provider for `RefreshTokenUseCase` instance.

```dart
/// Provider for [RefreshTokenUseCase] instance
/// 
/// This provider creates a singleton instance of [RefreshTokenUseCase]
/// that handles token refresh business logic.
final refreshTokenUseCaseProvider = Provider<RefreshTokenUseCase>((ref) {
  final repository = ref.watch<AuthRepository>(authRepositoryProvider);
  return RefreshTokenUseCase(repository);
});
```

### getCurrentUserUseCaseProvider

Provider for `GetCurrentUserUseCase` instance.

```dart
/// Provider for [GetCurrentUserUseCase] instance
/// 
/// This provider creates a singleton instance of [GetCurrentUserUseCase]
/// that handles getting the current authenticated user.
final getCurrentUserUseCaseProvider = Provider<GetCurrentUserUseCase>((ref) {
  final repository = ref.watch<AuthRepository>(authRepositoryProvider);
  return GetCurrentUserUseCase(repository);
});
```

### isAuthenticatedUseCaseProvider

Provider for `IsAuthenticatedUseCase` instance.

```dart
/// Provider for [IsAuthenticatedUseCase] instance
/// 
/// This provider creates a singleton instance of [IsAuthenticatedUseCase]
/// that handles checking if the user is authenticated.
final isAuthenticatedUseCaseProvider = Provider<IsAuthenticatedUseCase>((ref) {
  final repository = ref.watch<AuthRepository>(authRepositoryProvider);
  return IsAuthenticatedUseCase(repository);
});
```

---

## Usage Examples

### In Widgets

```dart
class LoginScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () async {
        final loginUseCase = ref.read(loginUseCaseProvider);
        final result = await loginUseCase('user@example.com', 'password');
        // Handle result...
      },
      child: Text('Login'),
    );
  }
}
```

### In Providers

```dart
final userProvider = FutureProvider<User?>((ref) async {
  final useCase = ref.read(getCurrentUserUseCaseProvider);
  final result = await useCase();
  return result.when(
    success: (user) => user,
    failureCallback: (_) => null,
  );
});
```

### Accessing Repository Directly

```dart
final authRepository = ref.watch(authRepositoryProvider);
final result = await authRepository.getCurrentUser();
```

---

## Dependency Graph

As built in `lib/features/auth/di/auth_providers.dart`:

```
authRepositoryProvider
  ├── authRemoteDataSourceProvider
  │     └── networkClientProvider   (read, to break the ApiClient cycle)
  ├── authLocalDataSourceProvider
  │     ├── keyValueStoreProvider
  │     └── tokenStoreProvider
  ├── networkClientProvider         (read, for its responseCache)
  └── sessionGenerationProvider

loginUseCaseProvider (and every other auth use case provider)
  └── authRepositoryProvider
```

<!-- symbol: lib/features/auth/di/auth_providers.dart authRepositoryProvider -->
<!-- symbol: lib/features/auth/di/auth_providers.dart authRemoteDataSourceProvider -->
<!-- symbol: lib/features/auth/di/auth_providers.dart authLocalDataSourceProvider -->
<!-- symbol: lib/features/auth/di/auth_providers.dart loginUseCaseProvider -->
<!-- symbol: lib/core/di/providers.dart networkClientProvider -->
<!-- symbol: lib/core/di/providers.dart keyValueStoreProvider -->
<!-- symbol: lib/core/di/providers.dart tokenStoreProvider -->
<!-- symbol: lib/core/session/session_providers.dart sessionGenerationProvider -->

---

## Related APIs

- [Repositories](repositories.md) - Repository interfaces
- [Use Cases](usecases.md) - Use case classes
- [Core - Storage](../../core/storage.md) - Storage services used by providers


