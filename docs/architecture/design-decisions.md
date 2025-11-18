# Design Decisions

This document explains the key design decisions in this Flutter Clean Architecture template, including the rationale behind each choice, alternatives considered, trade-offs, and when to reconsider.

## Overview

This guide covers the rationale behind major technical decisions:
- Routing solution (go_router)
- State management (Riverpod)
- Error handling (Result pattern)
- Logging strategy
- Storage approach (dual storage)
- HTTP client (Dio)

Each decision includes problem statements, alternatives considered, chosen solution, trade-offs, and migration guides.

---

## Table of Contents

- [Routing: go_router](#routing-go_router)
- [State Management: Riverpod](#state-management-riverpod)
- [Error Handling: Result Pattern](#error-handling-result-pattern)
- [Logging: Custom LoggingService](#logging-custom-loggingservice)
- [Storage: Dual Storage System](#storage-dual-storage-system)
- [HTTP Client: Dio](#http-client-dio)
- [Comparison Tables](#comparison-tables)
- [Migration Guides](#migration-guides)

---

## Routing: go_router

### Problem Statement

Flutter apps need a way to navigate between screens. The basic `Navigator` API is imperative and doesn't handle:
- Deep linking
- URL-based navigation
- Authentication-based routing
- Type-safe route definitions
- Declarative routing configuration

### Alternatives Considered

#### 1. **Basic Navigator (Flutter SDK)**
**Pros:**
- ✅ No dependencies
- ✅ Simple for basic navigation
- ✅ Built into Flutter

**Cons:**
- ❌ No deep linking support
- ❌ Imperative API (harder to reason about)
- ❌ No URL-based navigation
- ❌ Manual route management
- ❌ No type safety

**When to use:**
- Very simple apps with 2-3 screens
- No deep linking requirements
- Prototypes

#### 2. **AutoRoute**
**Pros:**
- ✅ Code generation (type-safe routes)
- ✅ Deep linking support
- ✅ Declarative configuration
- ✅ Good documentation

**Cons:**
- ❌ Code generation overhead
- ❌ Less flexible than go_router
- ❌ Smaller community
- ❌ Requires build_runner

**When to use:**
- Teams that prefer code generation
- Need strong type safety
- Don't mind build_runner

#### 3. **go_router (Chosen)**
**Pros:**
- ✅ Declarative routing
- ✅ Deep linking built-in
- ✅ URL-based navigation
- ✅ Authentication redirects
- ✅ Active maintenance (Flutter team)
- ✅ No code generation needed
- ✅ Good performance
- ✅ Excellent documentation

**Cons:**
- ❌ Learning curve (different from Navigator)
- ❌ Some boilerplate for complex routes

**When to use:**
- Production apps
- Need deep linking
- Want declarative routing
- Prefer runtime configuration

### Chosen Solution

**go_router** is used for routing in this template.

**Rationale:**
1. **Active Development**: Maintained by the Flutter team, ensuring long-term support
2. **Deep Linking**: Built-in support for web and mobile deep links
3. **Declarative**: Routes defined in one place, easier to understand
4. **Authentication**: Built-in redirect logic for protected routes
5. **No Code Generation**: Faster development, no build_runner needed
6. **Performance**: Efficient route matching and navigation

**Implementation:**
```dart
// lib/core/routing/app_router.dart
final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      // ... more routes
    ],
    redirect: (context, state) {
      // Authentication-based redirects
    },
  );
});
```

### Trade-offs

**Advantages:**
- ✅ Declarative routing configuration
- ✅ Deep linking support
- ✅ Authentication redirects
- ✅ Active maintenance

**Disadvantages:**
- ⚠️ Different API from Navigator (learning curve)
- ⚠️ Some boilerplate for complex nested routes
- ⚠️ Requires understanding of GoRouter concepts

### When to Reconsider

Consider alternatives if:
1. **Very simple app** (< 3 screens) → Use basic Navigator
2. **Need code generation** → Consider AutoRoute
3. **Team prefers imperative** → Use Navigator with a wrapper
4. **Specific AutoRoute features** → Evaluate AutoRoute

---

## State Management: Riverpod

### Problem Statement

Flutter apps need a way to manage state across the widget tree. State management should:
- Handle complex state logic
- Provide dependency injection
- Support testing
- Be performant
- Have good developer experience

### Alternatives Considered

#### 1. **Provider**
**Pros:**
- ✅ Simple API
- ✅ Official Flutter recommendation
- ✅ Good documentation
- ✅ Lightweight

**Cons:**
- ❌ Can have performance issues with complex state
- ❌ Less powerful than Riverpod
- ❌ No compile-time safety
- ❌ Limited dependency injection

**When to use:**
- Simple apps
- Team familiar with Provider
- Don't need advanced features

#### 2. **BLoC (Business Logic Component)**
**Pros:**
- ✅ Event-driven architecture
- ✅ Predictable state changes
- ✅ Good for complex state
- ✅ Strong testing support
- ✅ Large community

**Cons:**
- ❌ More boilerplate (Events, States, Bloc classes)
- ❌ Steeper learning curve
- ❌ Can be overkill for simple state
- ❌ Requires understanding of streams

**When to use:**
- Complex state management
- Event-driven requirements
- Team familiar with BLoC
- Need strict state management

#### 3. **Riverpod (Chosen)**
**Pros:**
- ✅ Compile-time safety
- ✅ Built-in dependency injection
- ✅ Excellent performance
- ✅ Less boilerplate than BLoC
- ✅ Great testing support
- ✅ Active development
- ✅ Works well with Clean Architecture

**Cons:**
- ❌ Learning curve (different from Provider)
- ❌ Requires understanding of providers
- ❌ Some concepts can be complex

**When to use:**
- Production apps
- Need dependency injection
- Want compile-time safety
- Prefer less boilerplate

### Chosen Solution

**Riverpod** is used for state management in this template.

**Rationale:**
1. **Compile-time Safety**: Catches errors at compile time, not runtime
2. **Dependency Injection**: Built-in DI system, perfect for Clean Architecture
3. **Performance**: Efficient rebuilds, only updates what changed
4. **Testing**: Easy to override providers in tests
5. **Less Boilerplate**: Simpler than BLoC for most use cases
6. **Clean Architecture**: Works naturally with repository pattern and use cases

**Implementation:**
```dart
// Domain layer - use case
final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return LoginUseCase(repository);
});

// Presentation layer - state management
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState.initial();
  
  Future<void> login(String email, String password) async {
    final useCase = ref.read(loginUseCaseProvider);
    final result = await useCase(email, password);
    // Handle result
  }
}
```

### Trade-offs

**Advantages:**
- ✅ Compile-time safety
- ✅ Built-in dependency injection
- ✅ Excellent performance
- ✅ Less boilerplate than BLoC
- ✅ Great for Clean Architecture

**Disadvantages:**
- ⚠️ Learning curve (provider concepts)
- ⚠️ Different from Provider (even though similar name)
- ⚠️ Some advanced features can be complex

### When to Reconsider

Consider alternatives if:
1. **Simple app** → Provider might be sufficient
2. **Event-driven requirements** → Consider BLoC
3. **Team familiar with BLoC** → BLoC might be better
4. **Need Provider compatibility** → Use Provider

---

## Error Handling: Result Pattern

### Problem Statement

Flutter apps need a way to handle errors from async operations. Traditional exception-based error handling:
- Doesn't force error handling (can be forgotten)
- Not type-safe
- Hard to distinguish error types
- Doesn't work well with functional programming

### Alternatives Considered

#### 1. **Exceptions (Traditional)**
**Pros:**
- ✅ Familiar to most developers
- ✅ Simple try-catch
- ✅ Works with existing Dart code

**Cons:**
- ❌ Not type-safe (can forget to catch)
- ❌ Doesn't force error handling
- ❌ Hard to distinguish error types
- ❌ Not functional-friendly

**When to use:**
- Simple error handling
- Team unfamiliar with Result pattern
- Quick prototypes

#### 2. **Either Pattern (fpdart)**
**Pros:**
- ✅ Functional programming approach
- ✅ Type-safe error handling
- ✅ Forces error handling
- ✅ Good for functional codebases

**Cons:**
- ❌ Requires functional programming knowledge
- ❌ Less familiar to most developers
- ❌ Additional dependency (fpdart)
- ❌ Can be verbose

**When to use:**
- Functional programming codebase
- Team familiar with functional patterns
- Want strong functional guarantees

#### 3. **Result Pattern (Chosen)**
**Pros:**
- ✅ Type-safe error handling
- ✅ Forces error handling (can't ignore errors)
- ✅ Clear success/failure distinction
- ✅ Works with pattern matching (Dart 3.0)
- ✅ No external dependencies
- ✅ Familiar to developers from other languages (Rust, Swift)

**Cons:**
- ❌ Different from exceptions (learning curve)
- ❌ Requires consistent usage
- ❌ Some boilerplate

**When to use:**
- Production apps
- Want type-safe error handling
- Prefer explicit error handling
- Using Dart 3.0+ pattern matching

### Chosen Solution

**Result Pattern** is used for error handling in this template.

**Rationale:**
1. **Type Safety**: Compiler forces error handling
2. **Explicit**: Success and failure are explicit in the type
3. **Pattern Matching**: Works great with Dart 3.0 sealed classes
4. **No Dependencies**: Pure Dart implementation
5. **Clean Architecture**: Fits well with use cases and repositories

**Implementation:**
```dart
// Result type
sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;
}

final class ResultFailure<T> extends Result<T> {
  const ResultFailure(this.failure);
  final Failure failure;
}

// Usage in use case
class LoginUseCase {
  Future<Result<User>> call(String email, String password) async {
    try {
      final user = await repository.login(email, password);
      return Success(user);
    } on AuthException catch (e) {
      return ResultFailure(AuthFailure(e.message));
    }
  }
}

// Usage in UI
final result = await loginUseCase(email, password);
result.when(
  success: (user) => navigateToHome(),
  failureCallback: (failure) => showError(failure.message),
);
```

### Trade-offs

**Advantages:**
- ✅ Type-safe error handling
- ✅ Forces explicit error handling
- ✅ Works with pattern matching
- ✅ No external dependencies
- ✅ Clear success/failure distinction

**Disadvantages:**
- ⚠️ Different from exceptions (learning curve)
- ⚠️ Requires consistent usage across codebase
- ⚠️ Some boilerplate for error mapping

### When to Reconsider

Consider alternatives if:
1. **Simple error handling** → Exceptions might be sufficient
2. **Functional programming** → Consider Either pattern
3. **Team unfamiliar with Result** → Start with exceptions, migrate later
4. **Legacy codebase** → Exceptions might be easier to integrate

---

## Logging: Custom LoggingService

### Problem Statement

Apps need logging for:
- Debugging during development
- Error tracking in production
- Performance monitoring
- User behavior analytics

Logging should:
- Support multiple outputs (console, file, remote)
- Be configurable per environment
- Have different log levels
- Be performant
- Support structured logging

### Alternatives Considered

#### 1. **print() / debugPrint()**
**Pros:**
- ✅ No dependencies
- ✅ Simple
- ✅ Built into Dart

**Cons:**
- ❌ No log levels
- ❌ No file logging
- ❌ No structured logging
- ❌ Can't disable in production
- ❌ Poor performance

**When to use:**
- Quick debugging
- Prototypes
- Very simple apps

#### 2. **developer.log()**
**Pros:**
- ✅ Built into Flutter
- ✅ Better than print()
- ✅ Supports log levels

**Cons:**
- ❌ No file logging
- ❌ No remote logging
- ❌ Limited features
- ❌ Not structured

**When to use:**
- Simple logging needs
- Don't need file/remote logging
- Want built-in solution

#### 3. **logger Package + Custom Service (Chosen)**
**Pros:**
- ✅ Multiple outputs (console, file, remote)
- ✅ Log levels (debug, info, warning, error)
- ✅ Structured logging
- ✅ Configurable per environment
- ✅ File rotation
- ✅ Good performance
- ✅ Extensible

**Cons:**
- ❌ Requires custom implementation
- ❌ Some setup needed
- ❌ Additional dependency

**When to use:**
- Production apps
- Need file/remote logging
- Want structured logging
- Need environment-specific configuration

### Chosen Solution

**Custom LoggingService** using the `logger` package is used in this template.

**Rationale:**
1. **Flexibility**: Can add multiple outputs (console, file, remote)
2. **Environment-aware**: Different behavior in dev vs production
3. **Structured Logging**: Supports context/metadata
4. **File Logging**: Logs to files for production debugging
5. **Performance**: Can be disabled in production
6. **Extensible**: Easy to add remote logging (e.g., Sentry, Firebase)

**Implementation:**
```dart
// LoggingService with multiple outputs
class LoggingService {
  LoggingService({
    bool? enableLogging,
    bool? enableFileLogging,
    bool? enableRemoteLogging,
  }) {
    final outputs = <LogOutput>[];
    
    if (kDebugMode) {
      outputs.add(ConsoleOutput());
    }
    
    if (enableFileLogging) {
      outputs.add(FileLogOutput());
    }
    
    if (enableRemoteLogging) {
      outputs.add(RemoteLogOutput());
    }
    
    _logger = Logger(
      output: MultiOutput(outputs),
      printer: AppConfig.isProduction 
        ? JsonLogFormatter() 
        : PrettyPrinter(),
    );
  }
  
  void debug(String message, {Map<String, dynamic>? context}) {
    _logger.d(_formatMessage(message, context));
  }
  
  // ... other log levels
}
```

### Trade-offs

**Advantages:**
- ✅ Multiple outputs
- ✅ Environment-aware
- ✅ Structured logging
- ✅ File rotation
- ✅ Extensible

**Disadvantages:**
- ⚠️ Custom implementation needed
- ⚠️ Some setup required
- ⚠️ Additional dependency

### When to Reconsider

Consider alternatives if:
1. **Very simple logging** → Use developer.log()
2. **No file logging needed** → Use developer.log()
3. **Want built-in only** → Use developer.log()
4. **Need specific logging service** → Integrate directly (e.g., Sentry)

---

## Storage: Dual Storage System

### Problem Statement

Apps need to store data locally. Different data has different security requirements:
- **Sensitive data** (tokens, passwords) → Needs encryption
- **Non-sensitive data** (preferences, cache) → Can use simple storage

Using one storage solution for everything is either:
- Overkill (encrypting everything)
- Insecure (storing tokens in plain text)

### Alternatives Considered

#### 1. **SharedPreferences Only**
**Pros:**
- ✅ Simple API
- ✅ No encryption overhead
- ✅ Fast

**Cons:**
- ❌ Not secure (plain text)
- ❌ Can't store sensitive data safely
- ❌ Security risk

**When to use:**
- No sensitive data
- Prototypes
- Internal tools

#### 2. **Secure Storage Only**
**Pros:**
- ✅ Secure for all data
- ✅ Encrypted storage

**Cons:**
- ❌ Slower (encryption overhead)
- ❌ Overkill for non-sensitive data
- ❌ More complex API

**When to use:**
- All data is sensitive
- Security is top priority
- Don't mind performance impact

#### 3. **Dual Storage System (Chosen)**
**Pros:**
- ✅ Right tool for the job
- ✅ Secure for sensitive data
- ✅ Fast for non-sensitive data
- ✅ Clear separation of concerns
- ✅ Unified interface (IStorageService)

**Cons:**
- ❌ Need to choose which storage to use
- ❌ Two storage systems to manage
- ❌ Some complexity

**When to use:**
- Production apps
- Mix of sensitive and non-sensitive data
- Want optimal performance and security

### Chosen Solution

**Dual Storage System** is used in this template:
- **StorageService** (SharedPreferences) → Non-sensitive data
- **SecureStorageService** (flutter_secure_storage) → Sensitive data

**Rationale:**
1. **Security**: Sensitive data is encrypted
2. **Performance**: Non-sensitive data is fast
3. **Unified Interface**: Both implement `IStorageService`
4. **Clear Separation**: Easy to know which to use
5. **Best of Both**: Security where needed, performance where possible

**Implementation:**
```dart
// Unified interface
abstract class IStorageService {
  Future<String?> getString(String key);
  Future<bool> setString(String key, String value);
  // ... other methods
}

// Non-sensitive storage
class StorageService implements IStorageService {
  // Uses SharedPreferences
}

// Sensitive storage
class SecureStorageService implements IStorageService {
  // Uses flutter_secure_storage
  // Android: EncryptedSharedPreferences
  // iOS: Keychain
}

// Usage
// Non-sensitive
final storage = ref.read(storageServiceProvider);
await storage.setString('theme', 'dark');

// Sensitive
final secureStorage = ref.read(secureStorageServiceProvider);
await secureStorage.setString('auth_token', token);
```

### Trade-offs

**Advantages:**
- ✅ Secure for sensitive data
- ✅ Fast for non-sensitive data
- ✅ Unified interface
- ✅ Clear separation

**Disadvantages:**
- ⚠️ Need to choose which storage
- ⚠️ Two systems to manage
- ⚠️ Some complexity

### When to Reconsider

Consider alternatives if:
1. **No sensitive data** → Use SharedPreferences only
2. **All data sensitive** → Use SecureStorage only
3. **Want simplicity** → Choose one, accept trade-offs

---

## HTTP Client: Dio

### Problem Statement

Apps need to make HTTP requests. The basic `http` package:
- Limited interceptor support
- No request/response transformation
- Basic error handling
- No built-in retry logic

### Alternatives Considered

#### 1. **http Package (Flutter SDK)**
**Pros:**
- ✅ No dependencies
- ✅ Simple API
- ✅ Built into Flutter

**Cons:**
- ❌ Limited interceptor support
- ❌ Basic error handling
- ❌ No request/response transformation
- ❌ No retry logic

**When to use:**
- Simple HTTP requests
- No interceptors needed
- Want minimal dependencies

#### 2. **Dio (Chosen)**
**Pros:**
- ✅ Powerful interceptor system
- ✅ Request/response transformation
- ✅ Built-in retry logic
- ✅ Good error handling
- ✅ Cancel tokens
- ✅ Form data support
- ✅ Active maintenance

**Cons:**
- ❌ Additional dependency
- ❌ More complex than http
- ❌ Learning curve

**When to use:**
- Production apps
- Need interceptors
- Want advanced features
- Need retry logic

### Chosen Solution

**Dio** is used as the HTTP client in this template.

**Rationale:**
1. **Interceptors**: Perfect for auth, logging, caching, error handling
2. **Error Handling**: Easy to convert DioException to domain exceptions
3. **Retry Logic**: Built-in support for retrying failed requests
4. **Active Maintenance**: Well-maintained package
5. **Features**: Cancel tokens, form data, file uploads

**Implementation:**
```dart
// ApiClient with interceptors
class ApiClient {
  ApiClient({
    required StorageService storageService,
    required SecureStorageService secureStorageService,
    required AuthInterceptor authInterceptor,
    LoggingService? loggingService,
  }) : _dio = _createDio(
    storageService,
    secureStorageService,
    authInterceptor,
    loggingService,
  );
  
  static Dio _createDio(...) {
    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: Duration(seconds: AppConfig.apiConnectTimeout),
    ));
    
    // Add interceptors
    dio.interceptors.addAll([
      ErrorInterceptor(),           // Convert to domain exceptions
      PerformanceInterceptor(),     // Track performance
      CacheInterceptor(),           // Cache responses
      AuthInterceptor(),            // Add auth tokens
      ApiLoggingInterceptor(),     // Log requests/responses
    ]);
    
    return dio;
  }
}
```

### Trade-offs

**Advantages:**
- ✅ Powerful interceptor system
- ✅ Good error handling
- ✅ Retry logic
- ✅ Active maintenance

**Disadvantages:**
- ⚠️ Additional dependency
- ⚠️ More complex than http
- ⚠️ Learning curve

### When to Reconsider

Consider alternatives if:
1. **Simple HTTP requests** → Use http package
2. **No interceptors needed** → http might be sufficient
3. **Want minimal dependencies** → Use http package

---

## Comparison Tables

### Routing Solutions

| Feature | Navigator | go_router | AutoRoute |
|---------|-----------|-----------|-----------|
| **Deep Linking** | ❌ Manual | ✅ Built-in | ✅ Built-in |
| **Type Safety** | ❌ | ⚠️ Partial | ✅ Full (code gen) |
| **Declarative** | ❌ | ✅ | ✅ |
| **Auth Redirects** | ❌ Manual | ✅ Built-in | ✅ Built-in |
| **Code Generation** | ❌ | ❌ | ✅ Required |
| **Learning Curve** | ✅ Low | ⚠️ Medium | ⚠️ Medium |
| **Dependencies** | ✅ None | ⚠️ go_router | ⚠️ auto_route + code gen |
| **Maintenance** | ✅ Flutter team | ✅ Flutter team | ⚠️ Community |
| **Best For** | Simple apps | Production apps | Type-safe apps |

### State Management

| Feature | Provider | Riverpod | BLoC |
|---------|----------|----------|------|
| **Compile-time Safety** | ❌ | ✅ | ⚠️ Partial |
| **Dependency Injection** | ⚠️ Basic | ✅ Built-in | ⚠️ Manual |
| **Boilerplate** | ✅ Low | ⚠️ Medium | ❌ High |
| **Learning Curve** | ✅ Low | ⚠️ Medium | ❌ High |
| **Performance** | ⚠️ Good | ✅ Excellent | ✅ Excellent |
| **Testing** | ✅ Easy | ✅ Easy | ✅ Easy |
| **Event-driven** | ❌ | ❌ | ✅ |
| **Best For** | Simple apps | Production apps | Complex state |

### Error Handling Patterns

| Feature | Exceptions | Result Pattern | Either Pattern |
|---------|------------|----------------|----------------|
| **Type Safety** | ❌ | ✅ | ✅ |
| **Forces Handling** | ❌ | ✅ | ✅ |
| **Familiar** | ✅ | ⚠️ Medium | ❌ Low |
| **Dependencies** | ✅ None | ✅ None | ⚠️ fpdart |
| **Pattern Matching** | ⚠️ Partial | ✅ Full | ✅ Full |
| **Functional** | ❌ | ⚠️ Partial | ✅ Full |
| **Best For** | Simple apps | Production apps | Functional codebases |

---

## Migration Guides

### Switching to Different Routing Solution

#### From go_router to Navigator

1. **Remove go_router dependency**
   ```yaml
   # pubspec.yaml
   dependencies:
     # go_router: ^17.0.0  # Remove this
   ```

2. **Create Navigator wrapper**
   ```dart
   // lib/core/routing/navigator_service.dart
   class NavigatorService {
     static void push(BuildContext context, Widget screen) {
       Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
     }
     
     static void pushReplacement(BuildContext context, Widget screen) {
       Navigator.pushReplacement(
         context,
         MaterialPageRoute(builder: (_) => screen),
       );
     }
   }
   ```

3. **Update navigation calls**
   ```dart
   // Before (go_router)
   context.go(AppRoutes.home);
   
   // After (Navigator)
   NavigatorService.push(context, HomeScreen());
   ```

4. **Remove GoRouter setup**
   - Remove `goRouterProvider` from `lib/core/routing/app_router.dart`
   - Update `main.dart` to use `MaterialApp` instead of `MaterialApp.router`

#### From go_router to AutoRoute

1. **Add AutoRoute dependencies**
   ```yaml
   dependencies:
     auto_route: ^7.0.0
   dev_dependencies:
     auto_route_generator: ^7.0.0
     build_runner: ^2.4.0
   ```

2. **Create route definitions**
   ```dart
   // lib/core/routing/app_router.gr.dart (generated)
   @AutoRouterConfig()
   class AppRouter extends _$AppRouter {
     @override
     List<AutoRoute> get routes => [
       AutoRoute(page: LoginRoute.page, initial: true),
       AutoRoute(page: HomeRoute.page),
     ];
   }
   ```

3. **Update navigation**
   ```dart
   // Before (go_router)
   context.go(AppRoutes.home);
   
   // After (AutoRoute)
   context.router.push(const HomeRoute());
   ```

### Changing State Management

#### From Riverpod to Provider

1. **Replace dependencies**
   ```yaml
   dependencies:
     # flutter_riverpod: ^3.0.3  # Remove
     provider: ^6.0.0  # Add
   ```

2. **Convert providers**
   ```dart
   // Before (Riverpod)
   final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
     final repository = ref.watch(authRepositoryProvider);
     return LoginUseCase(repository);
   });
   
   // After (Provider)
   final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
     final repository = ref.watch(authRepositoryProvider);
     return LoginUseCase(repository);
   });
   ```

3. **Update widgets**
   ```dart
   // Before (Riverpod)
   class LoginScreen extends ConsumerWidget {
     @override
     Widget build(BuildContext context, WidgetRef ref) {
       final useCase = ref.watch(loginUseCaseProvider);
     }
   }
   
   // After (Provider)
   class LoginScreen extends StatelessWidget {
     @override
     Widget build(BuildContext context) {
       final useCase = Provider.of<LoginUseCase>(context);
     }
   }
   ```

4. **Update main.dart**
   ```dart
   // Before (Riverpod)
   runApp(
     const ProviderScope(
       child: MyApp(),
     ),
   );
   
   // After (Provider)
   runApp(
     MultiProvider(
       providers: [
         Provider<LoginUseCase>(create: (_) => LoginUseCase(...)),
       ],
       child: const MyApp(),
     ),
   );
   ```

#### From Riverpod to BLoC

See the comprehensive migration guide: `docs/guides/migration/from-bloc-to-riverpod.md` (reverse the steps)

### Using Different HTTP Client

#### From Dio to http

1. **Replace dependencies**
   ```yaml
   dependencies:
     # dio: ^5.9.0  # Remove
     http: ^1.0.0  # Add
   ```

2. **Create HTTP client wrapper**
   ```dart
   // lib/core/network/api_client.dart
   import 'package:http/http.dart' as http;
   
   class ApiClient {
     final String baseUrl;
     
     ApiClient({required this.baseUrl});
     
     Future<http.Response> get(String path) async {
       final uri = Uri.parse('$baseUrl$path');
       return await http.get(uri);
     }
     
     // ... other methods
   }
   ```

3. **Remove interceptors**
   - Interceptors are Dio-specific
   - Implement equivalent logic in ApiClient methods
   - Or use middleware pattern

4. **Update error handling**
   ```dart
   // Before (Dio)
   try {
     return await _dio.get(path);
   } on DioException catch (e) {
     throw ServerException(e.message);
   }
   
   // After (http)
   try {
     final response = await http.get(uri);
     if (response.statusCode >= 400) {
       throw ServerException('Server error', statusCode: response.statusCode);
     }
     return response;
   } catch (e) {
     throw NetworkException(e.toString());
   }
   ```

### Alternative Error Handling Patterns

#### From Result Pattern to Exceptions

1. **Update use cases**
   ```dart
   // Before (Result Pattern)
   Future<Result<User>> call(String email, String password) async {
     try {
       final user = await repository.login(email, password);
       return Success(user);
     } on AuthException catch (e) {
       return ResultFailure(AuthFailure(e.message));
     }
   }
   
   // After (Exceptions)
   Future<User> call(String email, String password) async {
     return await repository.login(email, password);
     // Exceptions bubble up automatically
   }
   ```

2. **Update UI handling**
   ```dart
   // Before (Result Pattern)
   final result = await loginUseCase(email, password);
   result.when(
     success: (user) => navigateToHome(),
     failureCallback: (failure) => showError(failure.message),
   );
   
   // After (Exceptions)
   try {
     final user = await loginUseCase(email, password);
     navigateToHome();
   } on AuthException catch (e) {
     showError(e.message);
   } catch (e) {
     showError('Unexpected error');
   }
   ```

3. **Remove Result type**
   - Remove `lib/core/utils/result.dart`
   - Update all repository interfaces
   - Update all use cases

#### From Result Pattern to Either Pattern

1. **Add fpdart dependency**
   ```yaml
   dependencies:
     fpdart: ^1.0.0
   ```

2. **Update Result to Either**
   ```dart
   // Before (Result Pattern)
   sealed class Result<T> {
     const Result();
   }
   
   // After (Either Pattern)
   import 'package:fpdart/fpdart.dart';
   
   // Use Either<Failure, T> instead of Result<T>
   ```

3. **Update use cases**
   ```dart
   // Before (Result Pattern)
   Future<Result<User>> call(String email, String password) async {
     try {
       final user = await repository.login(email, password);
       return Success(user);
     } on AuthException catch (e) {
       return ResultFailure(AuthFailure(e.message));
     }
   }
   
   // After (Either Pattern)
   Future<Either<Failure, User>> call(String email, String password) async {
     try {
       final user = await repository.login(email, password);
       return Right(user);
     } on AuthException catch (e) {
       return Left(AuthFailure(e.message));
     }
   }
   ```

4. **Update UI handling**
   ```dart
   // Before (Result Pattern)
   result.when(
     success: (user) => navigateToHome(),
     failureCallback: (failure) => showError(failure.message),
   );
   
   // After (Either Pattern)
   result.fold(
     (failure) => showError(failure.message),
     (user) => navigateToHome(),
   );
   ```

---

## Summary

This template makes deliberate choices for each major decision:

- **Routing**: go_router for declarative, deep-linkable routing
- **State Management**: Riverpod for compile-time safety and DI
- **Error Handling**: Result pattern for type-safe error handling
- **Logging**: Custom LoggingService for flexibility
- **Storage**: Dual system for optimal security and performance
- **HTTP Client**: Dio for powerful interceptors

Each decision includes:
- ✅ Problem statement
- ✅ Alternatives considered
- ✅ Chosen solution and rationale
- ✅ Trade-offs
- ✅ When to reconsider

Use this template as a starting point, understand the decisions, and adapt as needed for your specific requirements.

## Related Documentation

- **[Architecture Overview](overview.md)** - Why Clean Architecture, benefits, trade-offs, and learning resources
- **[Understanding the Codebase](../guides/understanding-codebase.md)** - Architecture and code organization
- **[Common Patterns](../api/examples/common-patterns.md)** - Common usage patterns and best practices
- **[Routing Guide](../guides/routing.md)** - GoRouter navigation and deep linking
- **[Migration Guides](../guides/migration/)** - Guides for migrating from other architectures
- **[API Documentation](../api/README.md)** - Complete API reference

