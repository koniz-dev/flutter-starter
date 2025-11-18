# API Integration Patterns

Patterns for integrating with APIs and handling responses.

## Overview

This guide covers common patterns for making API requests, handling responses, and managing errors.

---

## Making API Requests

### Using ApiClient Directly

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';

class UserService {
  UserService(this.apiClient);

  final ApiClient apiClient;

  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final response = await apiClient.get('/users/$userId');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateUserProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    final response = await apiClient.put(
      '/users/$userId',
      data: data,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteUser(String userId) async {
    await apiClient.delete('/users/$userId');
  }
}

// Provider
final userServiceProvider = Provider<UserService>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return UserService(apiClient);
});

// Usage
final userService = ref.read(userServiceProvider);
final profile = await userService.getUserProfile('123');
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

### With Custom Headers

```dart
final response = await apiClient.get(
  '/users',
  options: Options(
    headers: {'Custom-Header': 'value'},
  ),
);
```

---

## Error Handling

### Handling API Errors

```dart
import 'package:flutter_starter/core/errors/exceptions.dart';

Future<void> makeApiCall() async {
  try {
    final response = await apiClient.get('/endpoint');
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
}
```

### Using Result Pattern

```dart
final result = await useCase();
result.when(
  success: (data) {
    // Handle success
    print('Success: $data');
  },
  failureCallback: (failure) {
    // Handle different failure types
    if (failure is ServerFailure) {
      print('Server error: ${failure.message}');
    } else if (failure is NetworkFailure) {
      print('Network error: ${failure.message}');
    } else {
      print('Error: ${failure.message}');
    }
  },
);
```

### Comprehensive Error Handling

```dart
Future<void> handleOperation() async {
  final useCase = ref.read(someUseCaseProvider);
  final result = await useCase();

  result.when(
    success: (data) {
      // Handle success
      context.showSuccessSnackBar('Operation successful');
    },
    failureCallback: (failure) {
      // Handle different failure types
      String message;
      IconData icon;

      switch (failure.runtimeType) {
        case ServerFailure:
          message = 'Server error. Please try again later.';
          icon = Icons.error_outline;
          break;
        case NetworkFailure:
          message = 'Network error. Check your connection.';
          icon = Icons.wifi_off;
          break;
        case AuthFailure:
          message = 'Authentication failed. Please login again.';
          icon = Icons.lock_outline;
          _handleLogout();
          break;
        case ValidationFailure:
          message = failure.message;
          icon = Icons.warning_amber;
          break;
        default:
          message = failure.message;
          icon = Icons.error;
      }

      // Show error to user
      context.showErrorSnackBar(message);
      
      // Log error for debugging
      if (AppConfig.isDebugMode) {
        print('Error: ${failure.message}, Code: ${failure.code}');
      }
    },
  );
}
```

---

## Retry Logic

### Implementing Retry

```dart
Future<Result<T>> executeWithRetry<T>(
  Future<Result<T>> Function() operation, {
  int maxRetries = 3,
  Duration delay = const Duration(seconds: 1),
}) async {
  int attempts = 0;
  
  while (attempts < maxRetries) {
    final result = await operation();
    
    if (result.isSuccess) {
      return result;
    }
    
    final failure = result.failureOrNull;
    if (failure is NetworkFailure && attempts < maxRetries - 1) {
      // Retry on network failure
      await Future.delayed(delay * (attempts + 1));
      attempts++;
      continue;
    }
    
    // Don't retry for other failure types
    return result;
  }
  
  return result;
}

// Usage
final result = await executeWithRetry(() => loginUseCase(email, password));
```

---

## Authentication Flow

### Complete Login Flow

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/shared/extensions/context_extensions.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      context.showErrorSnackBar('Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);

    final loginUseCase = ref.read(loginUseCaseProvider);
    final result = await loginUseCase(email, password);

    setState(() => _isLoading = false);

    result.when(
      success: (user) {
        context.showSuccessSnackBar('Welcome back, ${user.name}!');
        context.navigateToReplacement(const HomeScreen());
      },
      failureCallback: (failure) {
        String errorMessage;
        if (failure is AuthFailure) {
          errorMessage = 'Invalid email or password';
        } else if (failure is NetworkFailure) {
          errorMessage = 'Network error. Please check your connection.';
        } else {
          errorMessage = failure.message;
        }
        context.showErrorSnackBar(errorMessage);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Check Authentication Status

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';

class AuthGuard extends ConsumerWidget {
  final Widget authenticatedChild;
  final Widget unauthenticatedChild;

  const AuthGuard({
    super.key,
    required this.authenticatedChild,
    required this.unauthenticatedChild,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticatedAsync = ref.watch(_isAuthenticatedProvider);

    return isAuthenticatedAsync.when(
      data: (isAuthenticated) {
        return isAuthenticated ? authenticatedChild : unauthenticatedChild;
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => unauthenticatedChild,
    );
  }
}

final _isAuthenticatedProvider = FutureProvider<bool>((ref) async {
  final useCase = ref.read(isAuthenticatedUseCaseProvider);
  final result = await useCase();
  return result.when(
    success: (isAuthenticated) => isAuthenticated,
    failureCallback: (_) => false,
  );
});
```

---

## Token Refresh

The `AuthInterceptor` automatically handles token refresh on 401 errors. No manual intervention needed in most cases.

### Manual Token Refresh

```dart
Future<void> _refreshToken() async {
  final refreshUseCase = ref.read(refreshTokenUseCaseProvider);
  final result = await refreshUseCase();

  result.when(
    success: (newToken) {
      // Token refreshed successfully
      // AuthInterceptor will use the new token automatically
      print('Token refreshed: $newToken');
    },
    failureCallback: (failure) {
      // Token refresh failed, logout user
      if (failure is AuthFailure) {
        _handleLogout();
      }
    },
  );
}
```

---

## Related APIs

- [Network APIs](../../core/network.md) - ApiClient and interceptors
- [Error Handling](../../core/errors.md) - Exception and Failure types
- [Common Patterns](common-patterns.md) - Common usage patterns

