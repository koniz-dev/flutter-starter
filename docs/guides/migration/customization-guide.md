# Customization Guide

This guide helps you customize the Flutter starter to fit your specific needs, including removing unused features, adding custom features, and adapting to specific requirements.

## Overview

This starter is designed to be flexible and customizable. You can:
- Remove features you don't need
- Add custom features
- Modify existing features
- Adapt to specific business requirements

## Removing Unused Features

### Step 1: Identify Unused Features

Review your project to identify features you don't need:

```bash
# Check feature directories
ls lib/features/

# Check core modules
ls lib/core/
```

### Step 2: Remove Feature Modules

#### Remove Authentication Feature

There is no auth strip flag. Use this procedure whether you are making an
anonymous app or replacing the sample with another authentication system:

1. In `lib/core/routing/routes_registry.dart`, remove the auth routing import
   and `buildAuthRoutes(ref)`. Replace `AuthSessionStatusNotifier` as the factory
   for `sessionStatusProvider` with your own `Notifier<SessionStatus>`.
   For an anonymous app its `build()` returns `SessionStatus.signedIn`.
   Keep the notifier-provider contract; a plain `Provider` returning a status
   is not a replacement. The redirect in `app_router.dart` already reads this
   core session seam and imports no auth feature, so it needs no auth-import
   removal or redirect rewrite.
2. In `lib/main.dart`, remove the two auth imports, the
   `...authModuleOverrides` composition-root binding, and the bootstrap await
   of `sessionRestorationProvider.future`. Keep storage, localization,
   logging and startup handling still used by the rest of your app. If keeping
   authenticated REST calls with a replacement auth system, supply its own
   restoration and the `tokenRefresherProvider` /
   `sessionTerminationSinkProvider` bindings used by the core interceptor.
3. Handle the home sign-out action explicitly. A replacement auth system
   binds `signOutProvider.overrideWith(...)` to its own logout operation at
   the composition root. An anonymous app removes the sign-out app-bar action
   in `lib/features/home/presentation/screens/home_screen.dart` and adapts
   the related tests. Core's default `signOutProvider` throws `StateError`;
   leaving the action after removing its binding causes an unhandled error.
4. Remove the sample implementation and its feature tests:

   ```bash
   rm -rf lib/features/auth test/features/auth
   ```

5. Adapt or remove shared consumers, not just the feature test directory:
   `test/helpers/signed_in_app.dart`, `test/helpers/mock_factories.dart`,
   `test/helpers/test_fixtures.dart` and its `helpers_test.dart` consumers,
   `test/acceptance/acceptance_helpers.dart`, and the demo import in
   `test/flutter_test_config.dart`. Review auth-dependent acceptance,
   core/session, startup, network, home/tasks/feature-flags routing and session,
   and login-theme tests too. Replace their auth-specific setup with your new
   session implementation, or remove tests for behavior your app removed.
6. Find remaining imports, provider wiring and documentation references:

   ```bash
   rg -n 'features/auth/|authModuleOverrides|authProvider|sessionRestorationProvider' lib test integration_test docs
   ```

   Some consumers read source files rather than importing them:
   `test/docs/auth_providers_quotes_test.dart` reads the deleted provider
   file, and documentation symbol directives point into auth sources.
   Remove or adapt those tests, auth API guides, source directives, quotations
   and inbound links. Documentation describing the removal itself can remain.
7. Run `flutter analyze`, `flutter test`, and `dart run tool/check_docs.dart`.
   Resolve remaining references before treating the removal as complete.

If your replacement still needs API credentials, keep the core token/storage
contracts it uses; see [Contracts and adapter map](../../architecture/contracts-map.md).

#### Remove Feature Flags

If you don't need feature flags:

<!-- strip:strip-tool start -->
Use the strip tool rather than deleting by hand - it also rewrites the files
that reference the slice:

```bash
dart run tool/strip_sample_features.dart --apply --remove-feature-flags
```
<!-- strip:strip-tool end -->

The feature-flags slice brings no dependency of its own (it stores overrides
in the same `shared_preferences` the app already uses), so `pubspec.yaml` needs
no change.

### Step 3: Remove Unused Dependencies

Review `pubspec.yaml` and remove unused dependencies:

```yaml
dependencies:
  # Remove if not using
  # equatable  # Only needed if using Equatable
  # freezed_annotation  # Only needed if using Freezed
  # json_annotation  # Only needed if using JSON serialization
```

**After removing dependencies:**
```bash
flutter pub get
flutter pub outdated  # Check for unused dependencies
```

### Step 4: Remove Unused Core Modules

#### Remove Localization

If you don't need internationalization:

```bash
# Remove localization files
rm -rf lib/core/localization
rm -rf lib/l10n

# Remove from pubspec.yaml
# Remove flutter_localizations

# Remove from main.dart
# Remove LocalizationsDelegates
```

**Update `pubspec.yaml`:**
```yaml
dependencies:
  # Remove if not using
  # flutter_localizations:
  #   sdk: flutter
  # intl: ^0.20.2  # Only needed for localization
```

**Update `lib/main.dart`:**
```dart
// Remove LocalizationsDelegates
// Remove supportedLocales
```

#### Remove Secure Storage

If you don't need secure storage:

```bash
# Remove secure storage service
rm lib/core/storage/secure_storage_service.dart

# Remove from providers
# Remove secureStorageServiceProvider

# Remove dependency
# Remove flutter_secure_storage from pubspec.yaml
```

### Step 5: Clean Up Tests

Remove tests for removed features:

```bash
# Remove the tests of each feature you removed
rm -rf test/features/auth

# Update test files that reference removed features
```

### Step 6: Update Documentation

Update your project documentation:

```bash
# Update README.md
# Remove references to removed features

# Update API documentation
# Remove docs for removed features
```

## Adding Custom Features

Follow [Adding a New Feature](../../api/examples/adding-features.md) for the
complete procedure: scaffold the slice, connect its data source and dependency
injection, add localized UI, register its route and home destination, and test
the feature.

## Adapting to Specific Needs

### Custom Network Configuration

Add to `ApiClient`, do not replace it. Its constructor builds the client in
`_createDio` (`lib/core/network/api_client.dart`): SSL pinning, the cache,
`AuthInterceptor` (the bearer token and 401 refresh), retry, logging,
performance and error mapping. A replacement class drops all of that, and
`apiClientProvider` no longer compiles against it.

To add an interceptor, insert it in the list `_createDio` installs. The order
matters - dio runs `onRequest` and `onError` in registration order:

```dart
dio.interceptors.addAll([
  cacheInterceptor,
  authInterceptor,
  // After AuthInterceptor if it needs the Authorization header; before
  // ErrorInterceptor, which ends the error chain, if it handles errors.
  MyTenantHeaderInterceptor(),
  RetryInterceptor(/* ... */),
  // ...
  ErrorInterceptor(), // stays last
]);
```

For a header on one call, pass it to that call:
`apiClient.get('/reports', headers: {'X-Tenant': tenantId})`.

<!-- symbol: lib/core/network/api_client.dart ApiClient._createDio -->

### Custom Storage Implementation

**Create custom storage service:**

```dart
// lib/core/storage/custom_storage_service.dart
abstract class CustomStorageService {
  Future<void> saveCustomData(String key, dynamic value);
  Future<dynamic> getCustomData(String key);
}

class CustomStorageServiceImpl implements CustomStorageService {
  CustomStorageServiceImpl(this.storageService);
  
  final StorageService storageService;
  
  @override
  Future<void> saveCustomData(String key, dynamic value) async {
    // Custom implementation
  }
  
  @override
  Future<dynamic> getCustomData(String key) async {
    // Custom implementation
  }
}
```

### Custom Error Handling

**Extend error types:**

```dart
// lib/core/errors/failures.dart
class CustomFailure extends Failure {
  const CustomFailure(super.message, {super.code});

  // Failure declares copyWith abstract; every failure implements it.
  @override
  Failure copyWith({String? message, String? code}) {
    return CustomFailure(message ?? this.message, code: code ?? this.code);
  }
}

// Update exception mapper
class ExceptionToFailureMapper {
  static Failure map(Exception exception) {
    if (exception is CustomException) {
      return CustomFailure(exception.message);
    }
    // ... other mappings
  }
}
```

### Custom Theme

**Modify `lib/shared/theme/app_theme.dart`:**

```dart
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      // Your custom theme
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
      ),
      // ... other customizations
    );
  }
  
  static ThemeData get darkTheme {
    return ThemeData(
      // Your custom dark theme
      brightness: Brightness.dark,
      // ... other customizations
    );
  }
}
```

## Best Practices

### 1. Follow Clean Architecture

- Keep domain layer framework-free
- Use repository pattern
- Separate concerns by layer

### 2. Use Dependency Injection

- Always use providers for dependencies
- Don't create instances directly
- Use `ref.read()` for one-time access
- Use `ref.watch()` for reactive access

### 3. Handle Errors Properly

- Use `Result<T>` pattern
- Map exceptions to failures
- Provide meaningful error messages

### 4. Write Tests

- Test use cases
- Test repositories
- Test UI components
- Maintain high test coverage

### 5. Document Your Code

- Add comments for complex logic
- Document public APIs
- Update README.md

## Common Customizations

### Adding a Database

```bash
# Add dependency
flutter pub add hive hive_flutter

# Create models
# Create data sources
# Update repository implementations
```

### Adding Routing

Routing already ships: `go_router` is a dependency, and every route is
registered in `lib/core/routing/routes_registry.dart`. To add a screen, follow
the [routing guide](../features/routing-guide.md).

### Adding Analytics

```bash
# Add dependency
flutter pub add firebase_analytics

# Create analytics service
# Add tracking calls
```

### Adding Push Notifications

```bash
# Add dependency
flutter pub add firebase_messaging

# Create notification service
# Handle notifications
```

## Related Documentation

- [Adding Features](../../api/examples/adding-features.md) - Detailed feature addition guide
- [Common Patterns](../../api/examples/common-patterns.md) - Common patterns and best practices
- [Understanding the Codebase](../onboarding/understanding-codebase.md) - Architecture overview


