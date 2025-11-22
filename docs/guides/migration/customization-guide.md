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

If you don't need authentication:

```bash
# Remove feature directory
rm -rf lib/features/auth

# Remove related providers from lib/core/di/providers.dart
# Remove auth-related imports and providers

# Remove auth-related tests
rm -rf test/features/auth
```

**Update `lib/core/di/providers.dart`:**
```dart
// Remove these providers:
// - authRepositoryProvider
// - loginUseCaseProvider
// - logoutUseCaseProvider
// - authProvider
```

#### Remove Feature Flags

If you don't need feature flags:

```bash
# Remove feature directory
rm -rf lib/features/feature_flags
rm -rf lib/core/feature_flags

# Remove from pubspec.yaml
# Remove firebase_remote_config dependency (if only used for feature flags)

# Remove providers
# Remove from lib/core/di/providers.dart
```

**Update `pubspec.yaml`:**
```yaml
dependencies:
  # Remove if only used for feature flags
  # firebase_core: ^4.2.1
  # firebase_remote_config: ^6.1.1
```

### Step 3: Remove Unused Dependencies

Review `pubspec.yaml` and remove unused dependencies:

```yaml
dependencies:
  # Remove if not using
  # equatable: ^2.0.7  # Only needed if using Equatable
  # freezed_annotation: ^3.1.0  # Only needed if using Freezed
  # json_annotation: ^4.9.0  # Only needed if using JSON serialization
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
# flutter_secure_storage: ^9.2.4
```

### Step 5: Clean Up Tests

Remove tests for removed features:

```bash
# Remove feature tests
rm -rf test/features/auth
rm -rf test/features/feature_flags

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

### Step 1: Create Feature Structure

Follow the Clean Architecture pattern:

```bash
# Create feature directory structure
mkdir -p lib/features/my_feature/{data,domain,presentation}

# Create subdirectories
mkdir -p lib/features/my_feature/data/{datasources,models,repositories}
mkdir -p lib/features/my_feature/domain/{entities,repositories,usecases}
mkdir -p lib/features/my_feature/presentation/{providers,screens,widgets}
```

### Step 2: Create Domain Layer

#### Create Entity

```dart
// lib/features/my_feature/domain/entities/my_entity.dart
import 'package:equatable/equatable.dart';

class MyEntity extends Equatable {
  const MyEntity({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}
```

#### Create Repository Interface

```dart
// lib/features/my_feature/domain/repositories/my_repository.dart
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/my_feature/domain/entities/my_entity.dart';

abstract class MyRepository {
  Future<Result<List<MyEntity>>> getItems();
  Future<Result<MyEntity>> getItemById(String id);
}
```

#### Create Use Cases

```dart
// lib/features/my_feature/domain/usecases/get_items_usecase.dart
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/my_feature/domain/entities/my_entity.dart';
import 'package:flutter_starter/features/my_feature/domain/repositories/my_repository.dart';

class GetItemsUseCase {
  GetItemsUseCase(this.repository);
  
  final MyRepository repository;
  
  Future<Result<List<MyEntity>>> call() async {
    return repository.getItems();
  }
}
```

### Step 3: Create Data Layer

#### Create Model

```dart
// lib/features/my_feature/data/models/my_entity_model.dart
import 'package:flutter_starter/features/my_feature/domain/entities/my_entity.dart';
import 'package:json_annotation/json_annotation.dart';

part 'my_entity_model.g.dart';

@JsonSerializable()
class MyEntityModel extends MyEntity {
  const MyEntityModel({
    required super.id,
    required super.name,
  });

  factory MyEntityModel.fromJson(Map<String, dynamic> json) =>
      _$MyEntityModelFromJson(json);

  Map<String, dynamic> toJson() => _$MyEntityModelToJson(this);

  MyEntity toEntity() {
    return MyEntity(
      id: id,
      name: name,
    );
  }
}
```

#### Create Data Source

```dart
// lib/features/my_feature/data/datasources/my_remote_datasource.dart
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/features/my_feature/data/models/my_entity_model.dart';

abstract class MyRemoteDataSource {
  Future<List<MyEntityModel>> getItems();
  Future<MyEntityModel> getItemById(String id);
}

class MyRemoteDataSourceImpl implements MyRemoteDataSource {
  MyRemoteDataSourceImpl(this.apiClient);
  
  final ApiClient apiClient;
  
  @override
  Future<List<MyEntityModel>> getItems() async {
    final response = await apiClient.get('/items');
    final data = response.data as Map<String, dynamic>;
    final itemsList = data['items'] as List;
    return itemsList
        .map((json) => MyEntityModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }
  
  // Implement other methods...
}
```

#### Create Repository Implementation

```dart
// lib/features/my_feature/data/repositories/my_repository_impl.dart
import 'package:flutter_starter/core/errors/exception_to_failure_mapper.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/my_feature/data/datasources/my_remote_datasource.dart';
import 'package:flutter_starter/features/my_feature/domain/entities/my_entity.dart';
import 'package:flutter_starter/features/my_feature/domain/repositories/my_repository.dart';

class MyRepositoryImpl implements MyRepository {
  MyRepositoryImpl(this.remoteDataSource);
  
  final MyRemoteDataSource remoteDataSource;
  
  @override
  Future<Result<List<MyEntity>>> getItems() async {
    try {
      final items = await remoteDataSource.getItems();
      return Success(items.map((m) => m.toEntity()).toList());
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    }
  }
  
  // Implement other methods...
}
```

### Step 4: Create Presentation Layer

#### Create Provider

```dart
// lib/features/my_feature/presentation/providers/my_feature_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/di/providers.dart';
import 'package:flutter_starter/features/my_feature/domain/entities/my_entity.dart';
import 'package:flutter_starter/features/my_feature/domain/usecases/get_items_usecase.dart';

class MyFeatureNotifier extends AsyncNotifier<List<MyEntity>> {
  @override
  Future<List<MyEntity>> build() async {
    final useCase = ref.read(getItemsUseCaseProvider);
    final result = await useCase();
    
    return result.when(
      success: (items) => items,
      failureCallback: (failure) => throw failure,
    );
  }
  
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final useCase = ref.read(getItemsUseCaseProvider);
      final result = await useCase();
      return result.when(
        success: (items) => items,
        failureCallback: (failure) => throw failure,
      );
    });
  }
}

final myFeatureProvider = AsyncNotifierProvider<MyFeatureNotifier, List<MyEntity>>(
  MyFeatureNotifier.new,
);
```

#### Create Screen

```dart
// lib/features/my_feature/presentation/screens/my_feature_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/features/my_feature/presentation/providers/my_feature_provider.dart';

class MyFeatureScreen extends ConsumerWidget {
  const MyFeatureScreen({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(myFeatureProvider);
    
    return Scaffold(
      appBar: AppBar(title: const Text('My Feature')),
      body: itemsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No items found'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text(item.name),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }
}
```

### Step 5: Add Providers

Add providers to `lib/core/di/providers.dart`:

```dart
// My Feature Providers
final myRemoteDataSourceProvider = Provider<MyRemoteDataSource>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return MyRemoteDataSourceImpl(apiClient);
});

final myRepositoryProvider = Provider<MyRepository>((ref) {
  final remoteDataSource = ref.read(myRemoteDataSourceProvider);
  return MyRepositoryImpl(remoteDataSource);
});

final getItemsUseCaseProvider = Provider<GetItemsUseCase>((ref) {
  final repository = ref.watch(myRepositoryProvider);
  return GetItemsUseCase(repository);
});
```

### Step 6: Generate Code

If using code generation:

```bash
# Generate Freezed files
flutter pub run build_runner build --delete-conflicting-outputs

# Or watch for changes
flutter pub run build_runner watch --delete-conflicting-outputs
```

## Adapting to Specific Needs

### Custom Network Configuration

**Modify `lib/core/network/api_client.dart`:**

```dart
class ApiClient {
  ApiClient(this.dio);
  
  final Dio dio;
  
  // Add custom interceptors
  void addCustomInterceptor(Interceptor interceptor) {
    dio.interceptors.add(interceptor);
  }
  
  // Add custom headers
  void setCustomHeaders(Map<String, String> headers) {
    dio.options.headers.addAll(headers);
  }
}
```

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
  const CustomFailure(super.message);
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

```bash
# Add dependency
flutter pub add go_router

# Create router configuration
# Update navigation
```

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

