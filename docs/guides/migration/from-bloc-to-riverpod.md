# Migration Guide: From BLoC to Riverpod

This guide helps you migrate your Flutter application from BLoC (Business Logic Component) to Riverpod state management used in this starter.

## Overview

**BLoC Pattern:**
- Uses `Bloc`/`Cubit` classes
- Events and States
- `BlocBuilder`, `BlocListener`, `BlocConsumer`
- `BlocProvider` for dependency injection

**Riverpod:**
- Uses `Provider`, `Notifier`, `FutureProvider`
- Direct state management
- `ConsumerWidget`, `Consumer`, `ref.watch`, `ref.read`
- Built-in dependency injection

## Key Differences

| Aspect | BLoC | Riverpod |
|--------|------|----------|
| **State Management** | Events → States | Direct state updates |
| **Dependency Injection** | BlocProvider | Provider (built-in) |
| **Widget Rebuilds** | BlocBuilder | ConsumerWidget/Consumer |
| **Async Operations** | Bloc with async events | FutureProvider/AsyncNotifier |
| **Code Generation** | Optional (bloc_code_generation) | Optional (riverpod_generator) |
| **Testing** | MockBloc | Override providers |

## Step-by-Step Migration

### Step 1: Map BLoC Components to Riverpod

| BLoC Component | Riverpod Equivalent |
|----------------|---------------------|
| `Bloc` | `Notifier` or `AsyncNotifier` |
| `Cubit` | `Notifier` |
| `BlocProvider` | `Provider` or `NotifierProvider` |
| `BlocBuilder` | `ConsumerWidget` or `Consumer` |
| `BlocListener` | `ref.listen` |
| `BlocConsumer` | `ConsumerWidget` with `ref.listen` |
| `BlocProvider.of(context)` | `ref.read(provider)` or `ref.watch(provider)` |

### Step 2: Migrate Cubit to Notifier

#### Before (BLoC Cubit):

```dart
// lib/features/counter/cubit/counter_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);
  
  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);
  void reset() => emit(0);
}
```

#### After (Riverpod Notifier):

```dart
// lib/features/counter/providers/counter_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CounterNotifier extends Notifier<int> {
  @override
  int build() => 0;
  
  void increment() => state = state + 1;
  void decrement() => state = state - 1;
  void reset() => state = 0;
}

final counterProvider = NotifierProvider<CounterNotifier, int>(
  CounterNotifier.new,
);
```

**Key Changes:**
- ✅ `Cubit<int>` → `Notifier<int>`
- ✅ `emit(state + 1)` → `state = state + 1`
- ✅ `super(0)` → `build() => 0`
- ✅ Added `NotifierProvider` for dependency injection

### Step 3: Migrate Bloc with Events to Notifier

#### Before (BLoC with Events):

```dart
// lib/features/auth/bloc/auth_event.dart
abstract class AuthEvent {}
class LoginRequested extends AuthEvent {
  final String email;
  final String password;
  LoginRequested(this.email, this.password);
}
class LogoutRequested extends AuthEvent {}

// lib/features/auth/bloc/auth_state.dart
abstract class AuthState {}
class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthSuccess extends AuthState {
  final User user;
  AuthSuccess(this.user);
}
class AuthFailure extends AuthState {
  final String error;
  AuthFailure(this.error);
}

// lib/features/auth/bloc/auth_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this.authRepository) : super(AuthInitial()) {
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }
  
  final AuthRepository authRepository;
  
  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.login(
        event.email,
        event.password,
      );
      emit(AuthSuccess(user));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }
  
  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await authRepository.logout();
    emit(AuthInitial());
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
  const factory AuthState.initial() = _AuthInitial;
  const factory AuthState.loading() = _AuthLoading;
  const factory AuthState.success(User user) = _AuthSuccess;
  const factory AuthState.failure(String error) = _AuthFailure;
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState.initial();
  
  Future<void> login(String email, String password) async {
    state = const AuthState.loading();
    
    final useCase = ref.read(loginUseCaseProvider);
    final result = await useCase(email, password);
    
    result.when(
      success: (user) {
        state = AuthState.success(user);
      },
      failureCallback: (failure) {
        state = AuthState.failure(failure.message);
      },
    );
  }
  
  Future<void> logout() async {
    final useCase = ref.read(logoutUseCaseProvider);
    final result = await useCase();
    
    result.when(
      success: (_) {
        state = const AuthState.initial();
      },
      failureCallback: (failure) {
        state = AuthState.failure(failure.message);
      },
    );
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
```

**Key Changes:**
- ✅ Events → Methods (direct method calls)
- ✅ Sealed classes with Freezed for state
- ✅ `ref.read` for accessing dependencies
- ✅ `Result<T>` pattern for error handling

### Step 4: Migrate Async Operations

#### Before (BLoC with Async Events):

```dart
// lib/features/products/bloc/products_bloc.dart
class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  ProductsBloc(this.repository) : super(ProductsInitial()) {
    on<LoadProducts>(_onLoadProducts);
  }
  
  final ProductRepository repository;
  
  Future<void> _onLoadProducts(
    LoadProducts event,
    Emitter<ProductsState> emit,
  ) async {
    emit(ProductsLoading());
    try {
      final products = await repository.getProducts();
      emit(ProductsLoaded(products));
    } catch (e) {
      emit(ProductsError(e.toString()));
    }
  }
}
```

#### After (Riverpod AsyncNotifier):

```dart
// lib/features/products/providers/products_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/features/products/domain/entities/product.dart';
import 'package:flutter_starter/features/products/domain/usecases/get_products_usecase.dart';

class ProductsNotifier extends AsyncNotifier<List<Product>> {
  @override
  Future<List<Product>> build() async {
    final useCase = ref.read(getProductsUseCaseProvider);
    final result = await useCase();
    
    return result.when(
      success: (products) => products,
      failureCallback: (failure) => throw failure,
    );
  }
  
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final useCase = ref.read(getProductsUseCaseProvider);
      final result = await useCase();
      return result.when(
        success: (products) => products,
        failureCallback: (failure) => throw failure,
      );
    });
  }
}

final productsProvider = AsyncNotifierProvider<ProductsNotifier, List<Product>>(
  ProductsNotifier.new,
);
```

**Key Changes:**
- ✅ `AsyncNotifier` for async operations
- ✅ `AsyncValue` handles loading/error/success states
- ✅ No manual state management for loading/error

### Step 5: Migrate UI Components

#### Before (BLoC UI):

```dart
// lib/features/counter/screens/counter_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/features/counter/cubit/counter_cubit.dart';

class CounterScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CounterCubit(),
      child: Scaffold(
        appBar: AppBar(title: Text('Counter')),
        body: BlocBuilder<CounterCubit, int>(
          builder: (context, count) {
            return Center(
              child: Text('Count: $count'),
            );
          },
        ),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              onPressed: () => context.read<CounterCubit>().increment(),
              child: Icon(Icons.add),
            ),
            SizedBox(height: 8),
            FloatingActionButton(
              onPressed: () => context.read<CounterCubit>().decrement(),
              child: Icon(Icons.remove),
            ),
          ],
        ),
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
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () => ref.read(counterProvider.notifier).increment(),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            onPressed: () => ref.read(counterProvider.notifier).decrement(),
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}
```

**Key Changes:**
- ✅ `StatelessWidget` → `ConsumerWidget`
- ✅ `BlocProvider` → Provider (defined separately)
- ✅ `BlocBuilder` → `ref.watch(provider)`
- ✅ `context.read<Cubit>()` → `ref.read(provider.notifier)`

### Step 6: Migrate BlocListener

#### Before (BLoC Listener):

```dart
BlocListener<AuthBloc, AuthState>(
  listener: (context, state) {
    if (state is AuthSuccess) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen()),
      );
    } else if (state is AuthFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.error)),
      );
    }
  },
  child: ...,
)
```

#### After (Riverpod ref.listen):

```dart
// In ConsumerWidget
@override
Widget build(BuildContext context, WidgetRef ref) {
  ref.listen<AuthState>(authProvider, (previous, next) {
    next.when(
      success: (user) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen()),
        );
      },
      failure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      },
      orElse: () {},
    );
  });
  
  // Rest of widget...
}
```

### Step 7: Migrate BlocConsumer

#### Before (BLoC Consumer):

```dart
BlocConsumer<AuthBloc, AuthState>(
  listener: (context, state) {
    if (state is AuthSuccess) {
      Navigator.pushReplacement(...);
    }
  },
  builder: (context, state) {
    if (state is AuthLoading) {
      return CircularProgressIndicator();
    }
    return LoginForm();
  },
)
```

#### After (Riverpod ConsumerWidget with ref.listen):

```dart
class LoginScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    
    // Listen for side effects
    ref.listen<AuthState>(authProvider, (previous, next) {
      next.when(
        success: (user) {
          Navigator.pushReplacement(...);
        },
        orElse: () {},
      );
    });
    
    // Build UI
    return authState.when(
      loading: () => CircularProgressIndicator(),
      orElse: () => LoginForm(),
    );
  }
}
```

### Step 8: Migrate Dependency Injection

#### Before (BLoC with BlocProvider):

```dart
// lib/main.dart
BlocProvider(
  create: (context) => AuthBloc(
    AuthRepositoryImpl(
      AuthRemoteDataSourceImpl(
        ApiClient(),
      ),
    ),
  ),
  child: MyApp(),
)

// In widget
final authBloc = context.read<AuthBloc>();
```

#### After (Riverpod Providers):

```dart
// lib/core/di/providers.dart
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return AuthRepositoryImpl(
    AuthRemoteDataSourceImpl(apiClient),
  );
});

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return LoginUseCase(repository);
});

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

// In widget
final authState = ref.watch(authProvider);
final useCase = ref.read(loginUseCaseProvider);
```

### Step 9: Update Main App

#### Before (BLoC):

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthBloc(...),
      child: MaterialApp(...),
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
    return MaterialApp(...);
  }
}
```

## Migration Checklist

### State Management
- [ ] Replace `Cubit` with `Notifier`
- [ ] Replace `Bloc` with `Notifier` or `AsyncNotifier`
- [ ] Convert events to methods
- [ ] Convert states to Freezed classes (optional but recommended)
- [ ] Replace `emit()` with `state =`

### UI Components
- [ ] Replace `StatelessWidget` with `ConsumerWidget`
- [ ] Replace `StatefulWidget` with `ConsumerStatefulWidget`
- [ ] Replace `BlocBuilder` with `ref.watch()`
- [ ] Replace `BlocListener` with `ref.listen()`
- [ ] Replace `BlocConsumer` with `ConsumerWidget` + `ref.listen()`
- [ ] Replace `context.read<Bloc>()` with `ref.read(provider.notifier)`

### Dependency Injection
- [ ] Remove `BlocProvider` from widget tree
- [ ] Create Riverpod providers in `lib/core/di/providers.dart`
- [ ] Wrap app with `ProviderScope`
- [ ] Update all dependency access to use `ref.read()` or `ref.watch()`

### Async Operations
- [ ] Use `AsyncNotifier` for async state
- [ ] Use `AsyncValue` for loading/error/success states
- [ ] Replace try-catch with `Result<T>` pattern

### Testing
- [ ] Replace `MockBloc` with provider overrides
- [ ] Update widget tests to use `ProviderScope`
- [ ] Update unit tests for notifiers

## Common Patterns Migration

### Pattern 1: Simple State

**Before (BLoC):**
```dart
class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);
  void increment() => emit(state + 1);
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

### Pattern 2: Complex State

**Before (BLoC):**
```dart
class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(AuthInitial());
  Future<void> login() async {
    emit(AuthLoading());
    try {
      final user = await repository.login();
      emit(AuthSuccess(user));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }
}
```

**After (Riverpod):**
```dart
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState.initial();
  
  Future<void> login() async {
    state = const AuthState.loading();
    final result = await useCase();
    result.when(
      success: (user) => state = AuthState.success(user),
      failureCallback: (failure) => state = AuthState.failure(failure.message),
    );
  }
}
```

### Pattern 3: Async Data Loading

**Before (BLoC):**
```dart
class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  ProductsBloc() : super(ProductsInitial()) {
    on<LoadProducts>(_onLoadProducts);
  }
  
  Future<void> _onLoadProducts(...) async {
    emit(ProductsLoading());
    try {
      final products = await repository.getProducts();
      emit(ProductsLoaded(products));
    } catch (e) {
      emit(ProductsError(e.toString()));
    }
  }
}
```

**After (Riverpod):**
```dart
class ProductsNotifier extends AsyncNotifier<List<Product>> {
  @override
  Future<List<Product>> build() async {
    final result = await useCase();
    return result.when(
      success: (products) => products,
      failureCallback: (failure) => throw failure,
    );
  }
}
```

## Benefits After Migration

1. **Simpler API**: Direct method calls instead of events
2. **Better Performance**: Fine-grained rebuilds with `ref.watch`
3. **Built-in DI**: No need for separate dependency injection
4. **Type Safety**: Compile-time safety with providers
5. **Less Boilerplate**: No need for events/state classes for simple cases
6. **Better Testing**: Easy to override providers in tests

## Next Steps

- Review [Understanding the Codebase](../onboarding/understanding-codebase.md)
- Check [Common Patterns](../../api/examples/common-patterns.md)
- See [Adding Features](../../api/examples/adding-features.md)

