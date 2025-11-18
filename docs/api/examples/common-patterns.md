# Common Patterns

Common usage patterns and best practices.

## Overview

This guide covers common patterns used throughout the Flutter Starter project.

---

## Result Pattern

All repository and use case methods return `Result<T>` for type-safe error handling.

### Basic Usage

```dart
final result = await loginUseCase('user@example.com', 'password');
result.when(
  success: (user) {
    // Handle success
    navigateToHome();
  },
  failureCallback: (failure) {
    // Handle failure
    if (failure is AuthFailure) {
      showError('Authentication failed');
    } else if (failure is NetworkFailure) {
      showError('Network error');
    }
  },
);
```

### Pattern Matching

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

---

## Dependency Injection Pattern

All dependencies are provided via Riverpod providers.

### Accessing Providers in Widgets

```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useCase = ref.read(loginUseCaseProvider);
    // Use useCase...
  }
}
```

### Accessing Providers in Other Providers

```dart
final myProvider = Provider<MyService>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return MyService(repository);
});
```

### Using ref.read vs ref.watch

- Use `ref.read` for one-time access (e.g., in callbacks)
- Use `ref.watch` for reactive access (e.g., in providers)

```dart
// One-time access
final useCase = ref.read(loginUseCaseProvider);

// Reactive access (rebuilds when provider changes)
final repository = ref.watch(authRepositoryProvider);
```

---

## Storage Patterns

### Using Regular Storage

```dart
final storage = ref.read(storageServiceProvider);

// Store values
await storage.setString('theme', 'dark');
await storage.setInt('user_id', 123);
await storage.setBool('notifications_enabled', value: true);

// Retrieve values
final theme = await storage.getString('theme');
final userId = await storage.getInt('user_id');
final notificationsEnabled = await storage.getBool('notifications_enabled');
```

### Using Secure Storage

```dart
final secureStorage = ref.read(secureStorageServiceProvider);

// Store sensitive data
await secureStorage.setString('token', token);
await secureStorage.setString('refresh_token', refreshToken);

// Retrieve sensitive data
final token = await secureStorage.getString('token');
```

### Storage Keys Pattern

```dart
class StorageKeys {
  static const String token = 'auth_token';
  static const String refreshToken = 'refresh_token';
  static const String userId = 'user_id';
  static const String theme = 'theme_mode';
}

// Usage
await secureStorage.setString(StorageKeys.token, token);
final token = await secureStorage.getString(StorageKeys.token);
```

---

## Configuration Patterns

### Accessing Configuration

```dart
import 'package:flutter_starter/core/config/app_config.dart';

void setupServices() {
  final baseUrl = AppConfig.baseUrl;
  final timeout = AppConfig.apiTimeout;
  
  if (AppConfig.enableLogging) {
    logger.info('App started with base URL: $baseUrl');
  }
  
  if (AppConfig.enableAnalytics) {
    analytics.initialize();
  }
}
```

### Environment-Specific Behavior

```dart
void configureApp() {
  if (AppConfig.isDevelopment) {
    // Development-specific setup
    enableDebugMenu();
    enableVerboseLogging();
  } else if (AppConfig.isStaging) {
    // Staging-specific setup
    enableBetaFeatures();
  } else if (AppConfig.isProduction) {
    // Production-specific setup
    disableDebugFeatures();
    enableProductionMonitoring();
  }
}
```

---

## Extension Patterns

### Context Extensions

```dart
// Access theme
final theme = context.theme;
final colors = context.colorScheme;

// Access screen size
if (context.isMobile) {
  return MobileLayout();
} else if (context.isTablet) {
  return TabletLayout();
} else {
  return DesktopLayout();
}

// Show snackbars
context.showSnackBar('Operation successful');
context.showErrorSnackBar('Operation failed');
context.showSuccessSnackBar('Success!');

// Navigation
context.navigateTo(NextScreen());
context.navigateToReplacement(HomeScreen());
context.pop();
```

### String Extensions

```dart
// Email validation
if (emailController.text.isValidEmail) {
  // Email is valid
} else {
  showError('Invalid email address');
}

// Phone validation
if (phoneController.text.isValidPhone) {
  // Phone is valid
}

// String manipulation
final capitalized = 'hello world'.capitalizeWords; // "Hello World"
final noSpaces = 'hello world'.removeWhitespace; // "helloworld"
```

### DateTime Extensions

```dart
final now = DateTime.now();

if (now.isToday) {
  print('Today');
} else if (now.isYesterday) {
  print('Yesterday');
} else if (now.isTomorrow) {
  print('Tomorrow');
}

final dateStr = now.toDateString(); // "2024-01-15"
final timeStr = now.toTimeString(); // "10:30:45"
final dateTimeStr = now.toDateTimeString(); // "2024-01-15 10:30:45"

final start = now.startOfDay;
final end = now.endOfDay;
```

---

## Best Practices

### 1. Always Use Result Pattern

```dart
// ✅ Good
final result = await useCase();
result.when(
  success: (data) => handleSuccess(data),
  failureCallback: (failure) => handleFailure(failure),
);

// ❌ Bad
try {
  final data = await useCase();
  handleSuccess(data);
} catch (e) {
  handleError(e);
}
```

### 2. Use Providers for Dependency Injection

```dart
// ✅ Good
final useCase = ref.read(loginUseCaseProvider);

// ❌ Bad
final repository = AuthRepositoryImpl(...);
final useCase = LoginUseCase(repository);
```

### 3. Handle Errors Appropriately

```dart
// ✅ Good - Type-safe error handling
result.when(
  success: (data) => ...,
  failureCallback: (failure) {
    if (failure is NetworkFailure) {
      // Handle network error
    } else if (failure is AuthFailure) {
      // Handle auth error
    }
  },
);

// ❌ Bad - Generic error handling
result.when(
  success: (data) => ...,
  failureCallback: (failure) => showError('Error occurred'),
);
```

### 4. Use Secure Storage for Sensitive Data

```dart
// ✅ Good - Use secure storage for tokens
await secureStorage.setString('token', token);

// ❌ Bad - Don't use regular storage for tokens
await storage.setString('token', token);
```

### 5. Leverage Extensions

```dart
// ✅ Good - Use extensions
if (email.isValidEmail) { ... }
context.showSnackBar('Message');

// ❌ Bad - Don't duplicate logic
final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
if (emailRegex.hasMatch(email)) { ... }
ScaffoldMessenger.of(context).showSnackBar(SnackBar(...));
```

### 6. Use Constants for Keys

```dart
// ✅ Good
class StorageKeys {
  static const String token = 'auth_token';
}

await storage.setString(StorageKeys.token, token);

// ❌ Bad
await storage.setString('token', token);
```

---

## Testing Patterns

### Testing Use Cases

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_starter/features/auth/domain/usecases/login_usecase.dart';
import 'package:flutter_starter/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late LoginUseCase useCase;
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
    useCase = LoginUseCase(mockRepository);
  });

  test('should return user when login succeeds', () async {
    // Arrange
    const email = 'user@example.com';
    const password = 'password123';
    const user = User(id: '1', email: email, name: 'John');
    
    when(() => mockRepository.login(email, password))
        .thenAnswer((_) async => const Success(user));

    // Act
    final result = await useCase(email, password);

    // Assert
    expect(result.isSuccess, true);
    expect(result.dataOrNull, user);
    verify(() => mockRepository.login(email, password)).called(1);
  });
}
```

---

## Related APIs

- [Result API](../../core/utils.md#result) - Result type documentation
- [Storage APIs](../../core/storage.md) - Storage services
- [Extensions](../../README.md#extensions) - Extension methods

