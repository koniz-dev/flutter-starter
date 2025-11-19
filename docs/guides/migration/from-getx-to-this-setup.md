# Migration Guide: From GetX to This Setup

This guide helps you migrate your Flutter application from GetX to Clean Architecture with Riverpod used in this starter.

## Overview

**GetX Architecture:**
- `GetxController` for state management
- `Get.find()` for dependency injection
- `GetX`, `Obx` for reactive UI
- `Get.to()`, `Get.back()` for navigation
- `GetStorage` for local storage
- `GetConnect` for HTTP requests

**This Starter (Clean Architecture + Riverpod):**
- `Notifier`/`AsyncNotifier` for state management
- Riverpod providers for dependency injection
- `ConsumerWidget` for reactive UI
- Standard Flutter navigation (or go_router)
- `StorageService`/`SecureStorageService` for storage
- `ApiClient` (Dio) for HTTP requests

## Key Differences

| Aspect | GetX | This Starter |
|--------|------|--------------|
| **State Management** | GetxController | Notifier/AsyncNotifier |
| **Dependency Injection** | Get.find() | ref.read()/ref.watch() |
| **Reactive UI** | GetX/Obx | ConsumerWidget/Consumer |
| **Navigation** | Get.to()/Get.back() | Navigator/go_router |
| **Storage** | GetStorage | StorageService/SecureStorageService |
| **HTTP** | GetConnect | ApiClient (Dio) |
| **Architecture** | Controller-based | Clean Architecture |

## Step-by-Step Migration

### Step 1: Map GetX Components

| GetX Component | This Starter Equivalent |
|----------------|------------------------|
| `GetxController` | `Notifier` or `AsyncNotifier` |
| `Get.put()` / `Get.lazyPut()` | `Provider` |
| `Get.find()` | `ref.read()` or `ref.watch()` |
| `GetX<Controller>()` | `ConsumerWidget` with `ref.watch()` |
| `Obx()` | `Consumer` widget |
| `Get.to()` | `Navigator.push()` or `go_router` |
| `Get.back()` | `Navigator.pop()` |
| `GetStorage` | `StorageService` or `SecureStorageService` |
| `GetConnect` | `ApiClient` |

### Step 2: Migrate GetxController to Notifier

#### Before (GetX Controller):

```dart
// lib/controllers/counter_controller.dart
import 'package:get/get.dart';

class CounterController extends GetxController {
  var count = 0.obs;
  
  void increment() => count.value++;
  void decrement() => count.value--;
  void reset() => count.value = 0;
  
  @override
  void onInit() {
    super.onInit();
    // Initialization logic
  }
  
  @override
  void onClose() {
    // Cleanup logic
    super.onClose();
  }
}
```

#### After (Riverpod Notifier):

```dart
// lib/features/counter/providers/counter_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CounterNotifier extends Notifier<int> {
  @override
  int build() {
    // Initialization logic (equivalent to onInit)
    return 0;
  }
  
  void increment() => state = state + 1;
  void decrement() => state = state - 1;
  void reset() => state = 0;
  
  // Cleanup is automatic in Riverpod
  // Use ref.onDispose() if needed
}

final counterProvider = NotifierProvider<CounterNotifier, int>(
  CounterNotifier.new,
);
```

**Key Changes:**
- ✅ `GetxController` → `Notifier<T>`
- ✅ `.obs` → Direct state management
- ✅ `count.value++` → `state = state + 1`
- ✅ `onInit()` → `build()` method
- ✅ `onClose()` → Automatic (or `ref.onDispose()`)

### Step 3: Migrate Complex Controller

#### Before (GetX Controller with Multiple States):

```dart
// lib/controllers/auth_controller.dart
import 'package:get/get.dart';

class AuthController extends GetxController {
  final _authService = Get.find<AuthService>();
  
  var isLoading = false.obs;
  var user = Rxn<User>();
  var error = ''.obs;
  
  @override
  void onInit() {
    super.onInit();
    checkAuthStatus();
  }
  
  Future<void> login(String email, String password) async {
    try {
      isLoading.value = true;
      error.value = '';
      
      final user = await _authService.login(email, password);
      this.user.value = user;
      
      Get.offAllNamed('/home');
    } catch (e) {
      error.value = e.toString();
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }
  
  Future<void> logout() async {
    await _authService.logout();
    user.value = null;
    Get.offAllNamed('/login');
  }
  
  Future<void> checkAuthStatus() async {
    final user = await _authService.getCurrentUser();
    this.user.value = user;
  }
}
```

#### After (Riverpod Notifier with Freezed State):

```dart
// lib/features/auth/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/domain/usecases/login_usecase.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_provider.freezed.dart';

@freezed
class AuthState with _$AuthState {
  const factory AuthState({
    User? user,
    @Default(false) bool isLoading,
    String? error,
  }) = _AuthState;
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Check auth status on initialization
    _checkAuthStatus();
    return const AuthState();
  }
  
  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    
    final useCase = ref.read(loginUseCaseProvider);
    final result = await useCase(email, password);
    
    result.when(
      success: (user) {
        state = state.copyWith(user: user, isLoading: false);
        // Navigation handled in UI layer
      },
      failureCallback: (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
    );
  }
  
  Future<void> logout() async {
    final useCase = ref.read(logoutUseCaseProvider);
    final result = await useCase();
    
    result.when(
      success: (_) {
        state = state.copyWith(user: null);
        // Navigation handled in UI layer
      },
      failureCallback: (failure) {
        state = state.copyWith(error: failure.message);
      },
    );
  }
  
  Future<void> _checkAuthStatus() async {
    final useCase = ref.read(getCurrentUserUseCaseProvider);
    final result = await useCase();
    
    result.when(
      success: (user) {
        state = state.copyWith(user: user);
      },
      failureCallback: (_) {
        // User not authenticated
      },
    );
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
```

**Key Changes:**
- ✅ Multiple `.obs` variables → Single state object
- ✅ `Get.find<Service>()` → `ref.read(provider)`
- ✅ `Get.snackbar()` → Handled in UI layer
- ✅ `Get.offAllNamed()` → Handled in UI layer
- ✅ Error handling with `Result<T>` pattern

### Step 4: Migrate Dependency Injection

#### Before (GetX DI):

```dart
// lib/main.dart
void main() {
  Get.put(AuthService());
  Get.lazyPut(() => AuthRepository());
  Get.lazyPut(() => ProductService());
  
  runApp(MyApp());
}

// In controller
class AuthController extends GetxController {
  final _authService = Get.find<AuthService>();
  final _repository = Get.find<AuthRepository>();
}
```

#### After (Riverpod Providers):

```dart
// lib/core/di/providers.dart
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final productServiceProvider = Provider<ProductService>((ref) {
  return ProductService();
});

// In notifier
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final authService = ref.read(authServiceProvider);
    final repository = ref.read(authRepositoryProvider);
    // Use services...
  }
}
```

**Key Changes:**
- ✅ `Get.put()` → `Provider` (singleton by default)
- ✅ `Get.lazyPut()` → `Provider` (lazy by default)
- ✅ `Get.find<T>()` → `ref.read(provider)` or `ref.watch(provider)`

### Step 5: Migrate UI Components

#### Before (GetX UI):

```dart
// lib/screens/counter_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:my_app/controllers/counter_controller.dart';

class CounterScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CounterController());
    
    return Scaffold(
      appBar: AppBar(title: Text('Counter')),
      body: Center(
        child: Obx(() => Text('Count: ${controller.count.value}')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => controller.increment(),
        child: Icon(Icons.add),
      ),
    );
  }
}
```

#### After (Riverpod UI):

```dart
// lib/features/counter/screens/counter_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_app/features/counter/providers/counter_provider.dart';

class CounterScreen extends ConsumerWidget {
  const CounterScreen({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    
    return Scaffold(
      appBar: AppBar(title: const Text('Counter')),
      body: Center(
        child: Text('Count: $count'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ref.read(counterProvider.notifier).increment(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

**Key Changes:**
- ✅ `StatelessWidget` → `ConsumerWidget`
- ✅ `Get.put()` → Provider (defined separately)
- ✅ `Obx()` → `ref.watch()` (automatic rebuilds)
- ✅ `controller.count.value` → Direct value access

### Step 6: Migrate Navigation

#### Before (GetX Navigation):

```dart
// Navigate to screen
Get.to(() => NextScreen());
Get.toNamed('/next');
Get.off(() => NextScreen()); // Replace current
Get.offAll(() => HomeScreen()); // Clear stack
Get.back(); // Go back

// With arguments
Get.to(() => ProductScreen(), arguments: {'id': productId});
final args = Get.arguments;

// With parameters
Get.toNamed('/product/:id', parameters: {'id': productId});
final params = Get.parameters;
```

#### After (Standard Flutter Navigation):

```dart
// Navigate to screen
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => NextScreen()),
);

// Replace current
Navigator.pushReplacement(
  context,
  MaterialPageRoute(builder: (_) => NextScreen()),
);

// Clear stack
Navigator.pushAndRemoveUntil(
  context,
  MaterialPageRoute(builder: (_) => HomeScreen()),
  (route) => false,
);

// Go back
Navigator.pop(context);

// With arguments (using constructor)
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => ProductScreen(productId: productId),
  ),
);

// Or use go_router (recommended for complex navigation)
// See: https://pub.dev/packages/go_router
```

**Key Changes:**
- ✅ `Get.to()` → `Navigator.push()`
- ✅ `Get.off()` → `Navigator.pushReplacement()`
- ✅ `Get.offAll()` → `Navigator.pushAndRemoveUntil()`
- ✅ `Get.back()` → `Navigator.pop()`
- ✅ Arguments passed via constructor instead of `Get.arguments`

### Step 7: Migrate Storage

#### Before (GetStorage):

```dart
// Setup
final box = GetStorage();

// Write
await box.write('key', 'value');
await box.write('user_id', 123);
await box.write('is_logged_in', true);

// Read
final value = box.read('key');
final userId = box.read('user_id');
final isLoggedIn = box.read('is_logged_in');

// Remove
await box.remove('key');
await box.erase(); // Clear all
```

#### After (StorageService):

```dart
// In provider
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

// Usage
final storage = ref.read(storageServiceProvider);

// Write
await storage.setString('key', 'value');
await storage.setInt('user_id', 123);
await storage.setBool('is_logged_in', true);

// Read
final value = await storage.getString('key');
final userId = await storage.getInt('user_id');
final isLoggedIn = await storage.getBool('is_logged_in');

// Remove
await storage.remove('key');
await storage.clear(); // Clear all
```

**For Sensitive Data (Tokens, Passwords):**

```dart
// Use SecureStorageService
final secureStorage = ref.read(secureStorageServiceProvider);

await secureStorage.setString('token', token);
final token = await secureStorage.getString('token');
```

**Key Changes:**
- ✅ `GetStorage` → `StorageService` or `SecureStorageService`
- ✅ `box.write()` → `storage.setString()` / `setInt()` / `setBool()`
- ✅ `box.read()` → `storage.getString()` / `getInt()` / `getBool()`
- ✅ `box.remove()` → `storage.remove()`
- ✅ `box.erase()` → `storage.clear()`

### Step 8: Migrate HTTP Requests

#### Before (GetConnect):

```dart
// lib/services/api_service.dart
import 'package:get/get.dart';

class ApiService extends GetConnect {
  @override
  void onInit() {
    httpClient.baseUrl = 'https://api.example.com';
    httpClient.timeout = Duration(seconds: 30);
  }
  
  Future<Response> getProducts() async {
    return await get('/products');
  }
  
  Future<Response> login(String email, String password) async {
    return await post('/login', {
      'email': email,
      'password': password,
    });
  }
}

// Usage
final apiService = Get.find<ApiService>();
final response = await apiService.getProducts();
```

#### After (ApiClient with Dio):

```dart
// lib/core/network/api_client.dart
import 'package:dio/dio.dart';
import 'package:flutter_starter/core/config/app_config.dart';

class ApiClient {
  ApiClient(this.dio);
  
  final Dio dio;
  
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return dio.get(path, queryParameters: queryParameters);
  }
  
  Future<Response> post(String path, {dynamic data}) async {
    return dio.post(path, data: data);
  }
  
  // Other methods...
}

// Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: Duration(seconds: AppConfig.apiConnectTimeout),
      receiveTimeout: Duration(seconds: AppConfig.apiReceiveTimeout),
    ),
  );
  return ApiClient(dio);
});

// Usage in data source
class ProductRemoteDataSource {
  ProductRemoteDataSource(this.apiClient);
  
  final ApiClient apiClient;
  
  Future<List<ProductModel>> getProducts() async {
    final response = await apiClient.get('/products');
    // Parse response...
  }
}
```

**Key Changes:**
- ✅ `GetConnect` → `ApiClient` (Dio wrapper)
- ✅ `httpClient.baseUrl` → `BaseOptions` in Dio
- ✅ Direct API calls → Through data sources in Clean Architecture

### Step 9: Migrate Snackbars and Dialogs

#### Before (GetX):

```dart
Get.snackbar('Title', 'Message');
Get.snackbar('Error', 'Something went wrong', 
  snackPosition: SnackPosition.BOTTOM,
  backgroundColor: Colors.red,
);

Get.dialog(AlertDialog(...));
Get.defaultDialog(title: 'Title', middleText: 'Message');
Get.bottomSheet(Container(...));
```

#### After (Standard Flutter):

```dart
// Snackbar
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Message'),
    backgroundColor: Colors.red,
  ),
);

// Or use extension (if available)
context.showSnackBar('Message');
context.showErrorSnackBar('Error message');

// Dialog
showDialog(
  context: context,
  builder: (_) => AlertDialog(
    title: Text('Title'),
    content: Text('Message'),
    actions: [...],
  ),
);

// Bottom sheet
showModalBottomSheet(
  context: context,
  builder: (_) => Container(...),
);
```

### Step 10: Update Main App

#### Before (GetX):

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

void main() {
  Get.put(AuthService());
  Get.put(StorageService());
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'My App',
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => HomeScreen()),
        GetPage(name: '/login', page: () => LoginScreen()),
      ],
    );
  }
}
```

#### After (Riverpod):

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/config/env_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment configuration
  await EnvConfig.load();
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      initialRoute: '/',
      routes: {
        '/': (context) => HomeScreen(),
        '/login': (context) => LoginScreen(),
      },
    );
  }
}
```

**Key Changes:**
- ✅ `GetMaterialApp` → `MaterialApp`
- ✅ `Get.put()` → Providers (defined separately)
- ✅ `getPages` → `routes` or use `go_router`
- ✅ Wrap with `ProviderScope`

## Migration Checklist

### State Management
- [ ] Replace `GetxController` with `Notifier` or `AsyncNotifier`
- [ ] Replace `.obs` with direct state management
- [ ] Convert `onInit()` to `build()` method
- [ ] Remove `onClose()` (automatic in Riverpod)

### Dependency Injection
- [ ] Replace `Get.put()` with `Provider`
- [ ] Replace `Get.lazyPut()` with `Provider`
- [ ] Replace `Get.find<T>()` with `ref.read(provider)`
- [ ] Create providers in `lib/core/di/providers.dart`

### UI Components
- [ ] Replace `StatelessWidget` with `ConsumerWidget`
- [ ] Replace `GetX<Controller>()` with `ref.watch(provider)`
- [ ] Replace `Obx()` with `Consumer` or `ref.watch()`
- [ ] Remove `Get.put()` from widget tree

### Navigation
- [ ] Replace `Get.to()` with `Navigator.push()`
- [ ] Replace `Get.off()` with `Navigator.pushReplacement()`
- [ ] Replace `Get.offAll()` with `Navigator.pushAndRemoveUntil()`
- [ ] Replace `Get.back()` with `Navigator.pop()`
- [ ] Replace `Get.arguments` with constructor parameters
- [ ] Consider using `go_router` for complex navigation

### Storage
- [ ] Replace `GetStorage` with `StorageService`
- [ ] Replace `box.write()` with `storage.setString()` / `setInt()` / `setBool()`
- [ ] Replace `box.read()` with `storage.getString()` / `getInt()` / `getBool()`
- [ ] Use `SecureStorageService` for sensitive data

### HTTP Requests
- [ ] Replace `GetConnect` with `ApiClient` (Dio)
- [ ] Move API calls to data sources (Clean Architecture)
- [ ] Update base URL configuration

### UI Feedback
- [ ] Replace `Get.snackbar()` with `ScaffoldMessenger` or extensions
- [ ] Replace `Get.dialog()` with `showDialog()`
- [ ] Replace `Get.bottomSheet()` with `showModalBottomSheet()`

### Main App
- [ ] Replace `GetMaterialApp` with `MaterialApp`
- [ ] Wrap app with `ProviderScope`
- [ ] Remove `Get.put()` calls
- [ ] Update routing configuration

## Common Patterns Migration

### Pattern 1: Simple State

**Before (GetX):**
```dart
class CounterController extends GetxController {
  var count = 0.obs;
  void increment() => count.value++;
}
```

**After (Riverpod):**
```dart
class CounterNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void increment() => state = state + 1;
}
```

### Pattern 2: Reactive UI

**Before (GetX):**
```dart
Obx(() => Text('Count: ${controller.count.value}'))
```

**After (Riverpod):**
```dart
final count = ref.watch(counterProvider);
Text('Count: $count')
```

### Pattern 3: Dependency Access

**Before (GetX):**
```dart
final service = Get.find<AuthService>();
```

**After (Riverpod):**
```dart
final service = ref.read(authServiceProvider);
```

## Benefits After Migration

1. **Clean Architecture**: Better separation of concerns
2. **Type Safety**: Compile-time safety with providers
3. **Testability**: Easy to test with provider overrides
4. **Standard Flutter**: Uses standard Flutter patterns
5. **Better Performance**: Fine-grained rebuilds
6. **No Global State**: Explicit dependency management

## Next Steps

- Review [Understanding the Codebase](../onboarding/understanding-codebase.md)
- Check [Common Patterns](../../api/examples/common-patterns.md)
- See [Adding Features](../../api/examples/adding-features.md)
- Consider using [go_router](https://pub.dev/packages/go_router) for navigation

