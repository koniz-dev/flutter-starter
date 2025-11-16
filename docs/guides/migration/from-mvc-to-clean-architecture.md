# Migration Guide: From MVC to Clean Architecture

This guide helps you migrate your Flutter application from MVC (Model-View-Controller) architecture to Clean Architecture used in this starter.

## Overview

**MVC Architecture:**
- Models: Data structures
- Views: UI components
- Controllers: Business logic mixed with UI logic

**Clean Architecture:**
- **Domain Layer**: Business logic (entities, use cases, repository interfaces)
- **Data Layer**: Data sources and repository implementations
- **Presentation Layer**: UI components and state management
- **Core Layer**: Infrastructure (network, storage, config)

## Key Differences

| Aspect | MVC | Clean Architecture |
|--------|-----|-------------------|
| **Business Logic** | In Controllers | In Use Cases (Domain Layer) |
| **Data Access** | Direct in Controllers | Through Repository Pattern |
| **Dependencies** | Tight coupling | Dependency Inversion |
| **Testability** | Hard to test | Easy to test (isolated layers) |
| **State Management** | SetState/StatefulWidget | Riverpod Providers |

## Step-by-Step Migration

### Step 1: Identify Your MVC Components

Map your current structure:

```
lib/
├── models/          # Your MVC Models
├── views/           # Your MVC Views
└── controllers/     # Your MVC Controllers
```

### Step 2: Create Domain Layer

#### 2.1 Extract Entities from Models

**Before (MVC Model):**
```dart
// lib/models/user.dart
class User {
  final String id;
  final String name;
  final String email;
  
  User({required this.id, required this.name, required this.email});
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
    };
  }
}
```

**After (Clean Architecture Entity):**
```dart
// lib/features/auth/domain/entities/user.dart
import 'package:equatable/equatable.dart';

class User extends Equatable {
  const User({
    required this.id,
    required this.name,
    required this.email,
  });

  final String id;
  final String name;
  final String email;

  @override
  List<Object?> get props => [id, name, email];
}
```

**Key Changes:**
- ✅ Removed JSON serialization (moved to Data Layer)
- ✅ Added `Equatable` for value equality
- ✅ Made properties `const` where possible
- ✅ Pure business object (no framework dependencies)

#### 2.2 Create Repository Interfaces

**Before (MVC Controller with direct API calls):**
```dart
// lib/controllers/auth_controller.dart
class AuthController {
  final ApiService apiService;
  
  Future<User?> login(String email, String password) async {
    try {
      final response = await apiService.post('/login', {
        'email': email,
        'password': password,
      });
      return User.fromJson(response.data);
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }
}
```

**After (Clean Architecture Repository Interface):**
```dart
// lib/features/auth/domain/repositories/auth_repository.dart
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';

abstract class AuthRepository {
  Future<Result<User>> login(String email, String password);
  Future<Result<void>> logout();
  Future<Result<User>> getCurrentUser();
}
```

**Key Changes:**
- ✅ Abstract interface (no implementation)
- ✅ Returns `Result<T>` for type-safe error handling
- ✅ No direct API calls (abstraction)

#### 2.3 Create Use Cases

**Before (Business logic in Controller):**
```dart
// lib/controllers/auth_controller.dart
class AuthController {
  Future<void> login(String email, String password) async {
    if (!_validateEmail(email)) {
      _showError('Invalid email');
      return;
    }
    
    final user = await apiService.login(email, password);
    if (user != null) {
      await storage.saveUser(user);
      _navigateToHome();
    }
  }
}
```

**After (Clean Architecture Use Case):**
```dart
// lib/features/auth/domain/usecases/login_usecase.dart
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/domain/repositories/auth_repository.dart';

class LoginUseCase {
  LoginUseCase(this.repository);
  
  final AuthRepository repository;
  
  Future<Result<User>> call(String email, String password) async {
    // Business logic validation
    if (email.isEmpty || password.isEmpty) {
      return ResultFailure(ValidationFailure('Email and password are required'));
    }
    
    // Delegate to repository
    return repository.login(email, password);
  }
}
```

**Key Changes:**
- ✅ Single responsibility (one use case = one operation)
- ✅ Pure business logic (no UI dependencies)
- ✅ Testable in isolation

### Step 3: Create Data Layer

#### 3.1 Create Data Models

**After (Data Model with JSON serialization):**
```dart
// lib/features/auth/data/models/user_model.dart
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.name,
    required super.email,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  User toEntity() {
    return User(
      id: id,
      name: name,
      email: email,
    );
  }
}
```

#### 3.2 Create Data Sources

**After (Remote Data Source):**
```dart
// lib/features/auth/data/datasources/auth_remote_datasource.dart
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/features/auth/data/models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> login(String email, String password);
  Future<void> logout();
  Future<UserModel> getCurrentUser();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(this.apiClient);
  
  final ApiClient apiClient;
  
  @override
  Future<UserModel> login(String email, String password) async {
    final response = await apiClient.post('/login', data: {
      'email': email,
      'password': password,
    });
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }
  
  // Implement other methods...
}
```

#### 3.3 Create Repository Implementation

**After (Repository Implementation):**
```dart
// lib/features/auth/data/repositories/auth_repository_impl.dart
import 'package:flutter_starter/core/errors/exception_to_failure_mapper.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this.remoteDataSource);
  
  final AuthRemoteDataSource remoteDataSource;
  
  @override
  Future<Result<User>> login(String email, String password) async {
    try {
      final userModel = await remoteDataSource.login(email, password);
      return Success(userModel.toEntity());
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    }
  }
  
  // Implement other methods...
}
```

### Step 4: Create Presentation Layer

#### 4.1 Replace Controllers with Riverpod Providers

**Before (MVC Controller with StatefulWidget):**
```dart
// lib/views/login_screen.dart
class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _controller = AuthController();
  bool _isLoading = false;
  String? _error;
  
  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    final user = await _controller.login(
      _emailController.text,
      _passwordController.text,
    );
    
    setState(() {
      _isLoading = false;
      if (user == null) {
        _error = 'Login failed';
      }
    });
    
    if (user != null) {
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => HomeScreen(),
      ));
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? CircularProgressIndicator()
          : Column(
              children: [
                if (_error != null) Text(_error!),
                // Form fields...
                ElevatedButton(
                  onPressed: _login,
                  child: Text('Login'),
                ),
              ],
            ),
    );
  }
}
```

**After (Clean Architecture with Riverpod):**
```dart
// lib/features/auth/presentation/providers/auth_provider.dart
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
    return const AuthState();
  }
  
  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    
    final useCase = ref.read(loginUseCaseProvider);
    final result = await useCase(email, password);
    
    result.when(
      success: (user) {
        state = state.copyWith(
          user: user,
          isLoading: false,
        );
      },
      failureCallback: (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
    );
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
```

**After (UI with ConsumerWidget):**
```dart
// lib/features/auth/presentation/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    
    return Scaffold(
      body: authState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (authState.error != null)
                  Text(authState.error!, style: TextStyle(color: Colors.red)),
                // Form fields...
                ElevatedButton(
                  onPressed: () {
                    ref.read(authProvider.notifier).login(
                      _emailController.text,
                      _passwordController.text,
                    );
                  },
                  child: const Text('Login'),
                ),
              ],
            ),
    );
  }
}
```

**Key Changes:**
- ✅ State management moved to Riverpod providers
- ✅ UI is stateless (ConsumerWidget)
- ✅ Business logic separated from UI
- ✅ Reactive updates (automatic rebuilds)

### Step 5: Set Up Dependency Injection

**Add Providers:**
```dart
// lib/core/di/providers.dart

// Data Sources
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return AuthRemoteDataSourceImpl(apiClient);
});

// Repository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final remoteDataSource = ref.read(authRemoteDataSourceProvider);
  return AuthRepositoryImpl(remoteDataSource);
});

// Use Cases
final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return LoginUseCase(repository);
});
```

### Step 6: Update Main App

**Before (MVC):**
```dart
// lib/main.dart
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: LoginScreen(),
    );
  }
}
```

**After (Clean Architecture with Riverpod):**
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
      home: LoginScreen(),
    );
  }
}
```

## Migration Checklist

### Domain Layer
- [ ] Extract entities from models (remove JSON serialization)
- [ ] Create repository interfaces
- [ ] Create use cases for each business operation
- [ ] Add Equatable to entities

### Data Layer
- [ ] Create data models (with JSON serialization)
- [ ] Create remote data sources
- [ ] Create local data sources (if needed)
- [ ] Implement repository interfaces
- [ ] Add exception to failure mapping

### Presentation Layer
- [ ] Replace StatefulWidget with ConsumerWidget
- [ ] Create Riverpod providers/notifiers
- [ ] Move state management to providers
- [ ] Update UI to use `ref.watch` and `ref.read`

### Infrastructure
- [ ] Set up dependency injection (providers)
- [ ] Wrap app with `ProviderScope`
- [ ] Configure environment variables
- [ ] Set up error handling

### Testing
- [ ] Write unit tests for use cases
- [ ] Write unit tests for repositories
- [ ] Write widget tests for UI
- [ ] Update integration tests

## Common Patterns Migration

### Pattern 1: Direct API Calls

**Before:**
```dart
final response = await http.post('/api/login', body: {...});
```

**After:**
```dart
final result = await loginUseCase(email, password);
result.when(
  success: (user) => ...,
  failureCallback: (failure) => ...,
);
```

### Pattern 2: State Management

**Before:**
```dart
setState(() {
  _isLoading = true;
});
```

**After:**
```dart
state = state.copyWith(isLoading: true);
```

### Pattern 3: Error Handling

**Before:**
```dart
try {
  final user = await login();
} catch (e) {
  print('Error: $e');
}
```

**After:**
```dart
final result = await loginUseCase(email, password);
result.when(
  success: (user) => ...,
  failureCallback: (failure) {
    if (failure is NetworkFailure) {
      // Handle network error
    } else if (failure is AuthFailure) {
      // Handle auth error
    }
  },
);
```

## Benefits After Migration

1. **Testability**: Business logic is isolated and easy to test
2. **Maintainability**: Clear separation of concerns
3. **Scalability**: Easy to add new features
4. **Flexibility**: Easy to swap implementations (e.g., different data sources)
5. **Type Safety**: Result pattern provides compile-time error handling

## Next Steps

- Review [Understanding the Codebase](../understanding-codebase.md)
- Check [Common Patterns](../../api/examples/common-patterns.md)
- See [Adding Features](../../api/examples/adding-features.md)

