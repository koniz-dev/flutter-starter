# Auth Providers

Riverpod providers for authentication dependency injection.

## Overview

All authentication-related providers are defined in `lib/core/di/providers.dart` using Riverpod.

---

## Data Source Providers

### authLocalDataSourceProvider

Provider for `AuthLocalDataSource` instance.

```dart
/// Provider for [AuthLocalDataSource] instance
/// 
/// This provider creates a singleton instance of [AuthLocalDataSourceImpl]
/// that handles local authentication data caching.
/// 
/// Uses:
/// - [SecureStorageService] for tokens (secure)
/// - [StorageService] for user data (non-sensitive)
final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  final secureStorageService = ref.watch(secureStorageServiceProvider);
  return AuthLocalDataSourceImpl(
    storageService: storageService,
    secureStorageService: secureStorageService,
  );
});
```

### authRemoteDataSourceProvider

Provider for `AuthRemoteDataSource` instance.

```dart
/// Provider for [AuthRemoteDataSource] instance
/// 
/// This provider creates a singleton instance of [AuthRemoteDataSourceImpl]
/// that handles remote authentication operations.
/// Uses ref.read to break circular dependency with apiClientProvider.
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final apiClient = ref.read<ApiClient>(apiClientProvider);
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
/// This provider creates a singleton instance of [AuthRepositoryImpl]
/// that coordinates between remote and local data sources.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remoteDataSource = ref.read<AuthRemoteDataSource>(
    authRemoteDataSourceProvider,
  );
  final localDataSource = ref.watch(authLocalDataSourceProvider);
  return AuthRepositoryImpl(
    remoteDataSource: remoteDataSource,
    localDataSource: localDataSource,
  );
});
```

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

```
authRepositoryProvider
  ├── authRemoteDataSourceProvider
  │     └── apiClientProvider
  └── authLocalDataSourceProvider
        ├── storageServiceProvider
        └── secureStorageServiceProvider

loginUseCaseProvider
  └── authRepositoryProvider
```

---

## Related APIs

- [Repositories](repositories.md) - Repository interfaces
- [Use Cases](usecases.md) - Use case classes
- [Core - Storage](../../core/storage.md) - Storage services used by providers

