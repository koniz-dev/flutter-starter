# Common Tasks

This guide covers common development tasks: adding features, API endpoints, screens, and working with state management.

## Adding a New Feature

Follow these steps to add a complete feature following clean architecture:

### Step 1: Create Domain Layer

1. **Create Entity** (`lib/features/<feature>/domain/entities/`):
   ```dart
   class Product extends Equatable {
     const Product({
       required this.id,
       required this.name,
     });
     
     final String id;
     final String name;
     
     @override
     List<Object?> get props => [id, name];
   }
   ```

2. **Create Repository Interface** (`lib/features/<feature>/domain/repositories/`):
   ```dart
   abstract class ProductRepository {
     Future<Result<List<Product>>> getProducts();
   }
   ```

3. **Create Use Cases** (`lib/features/<feature>/domain/usecases/`):
   ```dart
   class GetProductsUseCase {
     GetProductsUseCase(this.repository);
     final ProductRepository repository;
     
     Future<Result<List<Product>>> call() async {
       return repository.getProducts();
     }
   }
   ```

### Step 2: Create Data Layer

1. **Create Model** (`lib/features/<feature>/data/models/`):
   ```dart
   class ProductModel extends Product {
     const ProductModel({
       required super.id,
       required super.name,
     });
     
     factory ProductModel.fromJson(Map<String, dynamic> json) {
       return ProductModel(
         id: json['id'] as String,
         name: json['name'] as String,
       );
     }
     
     Map<String, dynamic> toJson() {
       return {'id': id, 'name': name};
     }
   }
   ```

2. **Create Remote Data Source** (`lib/features/<feature>/data/datasources/`):
   ```dart
   class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
     ProductRemoteDataSourceImpl(this.apiClient);
     final ApiClient apiClient;
     
     @override
     Future<List<ProductModel>> getProducts() async {
       final response = await apiClient.get('/products');
       // Parse and return
     }
   }
   ```

3. **Create Repository Implementation** (`lib/features/<feature>/data/repositories/`):
   ```dart
   class ProductRepositoryImpl implements ProductRepository {
     ProductRepositoryImpl({
       required this.remoteDataSource,
     });
     
     final ProductRemoteDataSource remoteDataSource;
     
     @override
     Future<Result<List<Product>>> getProducts() async {
       try {
         final products = await remoteDataSource.getProducts();
         return Success(products.map((m) => m.toEntity()).toList());
       } on Exception catch (e) {
         return ResultFailure(ExceptionToFailureMapper.map(e));
       }
     }
   }
   ```

### Step 3: Create Providers

Add to `lib/core/di/providers.dart`:

```dart
// Data source provider
final productRemoteDataSourceProvider = Provider<ProductRemoteDataSource>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return ProductRemoteDataSourceImpl(apiClient);
});

// Repository provider
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final remoteDataSource = ref.read(productRemoteDataSourceProvider);
  return ProductRepositoryImpl(remoteDataSource: remoteDataSource);
});

// Use case provider
final getProductsUseCaseProvider = Provider<GetProductsUseCase>((ref) {
  final repository = ref.watch(productRepositoryProvider);
  return GetProductsUseCase(repository);
});
```

### Step 4: Create UI

```dart
class ProductsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(_productsProvider);
    
    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      body: productsAsync.when(
        data: (products) => ListView.builder(...),
        loading: () => const CircularProgressIndicator(),
        error: (error, stack) => Text('Error: $error'),
      ),
    );
  }
}

final _productsProvider = FutureProvider<List<Product>>((ref) async {
  final useCase = ref.read(getProductsUseCaseProvider);
  final result = await useCase();
  return result.when(
    success: (products) => products,
    failureCallback: (failure) => throw failure,
  );
});
```

**Full Example**: See [Adding Features](../api/examples/adding-features.md) for a complete walkthrough.

## Adding a New API Endpoint

1. **Add to Remote Data Source**:
   ```dart
   // In ProductRemoteDataSource
   Future<ProductModel> getProductById(String id) async {
     final response = await apiClient.get('/products/$id');
     return ProductModel.fromJson(response.data);
   }
   ```

2. **Add to Repository Interface**:
   ```dart
   // In ProductRepository
   Future<Result<Product>> getProductById(String id);
   ```

3. **Implement in Repository**:
   ```dart
   // In ProductRepositoryImpl
   @override
   Future<Result<Product>> getProductById(String id) async {
     try {
       final product = await remoteDataSource.getProductById(id);
       return Success(product.toEntity());
     } on Exception catch (e) {
       return ResultFailure(ExceptionToFailureMapper.map(e));
     }
   }
   ```

4. **Create Use Case** (if needed):
   ```dart
   class GetProductByIdUseCase {
     GetProductByIdUseCase(this.repository);
     final ProductRepository repository;
     
     Future<Result<Product>> call(String id) async {
       return repository.getProductById(id);
     }
   }
   ```

5. **Add Provider**:
   ```dart
   final getProductByIdUseCaseProvider = Provider<GetProductByIdUseCase>((ref) {
     final repository = ref.watch(productRepositoryProvider);
     return GetProductByIdUseCase(repository);
   });
   ```

See [API Integration](../api/examples/api-integration.md) for more patterns.

## Adding New Screens

1. **Create Screen Widget**:
   ```dart
   class MyScreen extends ConsumerWidget {
     const MyScreen({super.key});
     
     @override
     Widget build(BuildContext context, WidgetRef ref) {
       // Access providers
       final useCase = ref.read(someUseCaseProvider);
       
       return Scaffold(
         appBar: AppBar(title: const Text('My Screen')),
         body: const Center(child: Text('My Screen Content')),
       );
     }
   }
   ```

2. **Add Navigation** (when routing is implemented):
   ```dart
   // Navigate to screen
   context.navigateTo(const MyScreen());
   ```

3. **Handle State**:
   ```dart
   // Using FutureProvider
   final dataProvider = FutureProvider<Data>((ref) async {
     final useCase = ref.read(getDataUseCaseProvider);
     final result = await useCase();
     return result.when(
       success: (data) => data,
       failureCallback: (failure) => throw failure,
     );
   });
   
   // In widget
   final dataAsync = ref.watch(dataProvider);
   dataAsync.when(
     data: (data) => Text(data.toString()),
     loading: () => const CircularProgressIndicator(),
     error: (error, stack) => Text('Error: $error'),
   );
   ```

## State Management Patterns

### Using Riverpod Providers

**Provider Types:**

1. **Provider** (read-only, singleton):
   ```dart
   final myServiceProvider = Provider<MyService>((ref) {
     return MyService();
   });
   ```

2. **FutureProvider** (async data):
   ```dart
   final productsProvider = FutureProvider<List<Product>>((ref) async {
     final useCase = ref.read(getProductsUseCaseProvider);
     final result = await useCase();
     return result.when(
       success: (products) => products,
       failureCallback: (failure) => throw failure,
     );
   });
   ```

3. **Notifier** (mutable state):
   ```dart
   class AuthNotifier extends Notifier<AuthState> {
     @override
     AuthState build() {
       return const AuthState();
     }
     
     Future<void> login(String email, String password) async {
       state = state.copyWith(isLoading: true);
       // ... login logic
     }
   }
   
   final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
     () => AuthNotifier(),
   );
   ```

### Accessing Providers

```dart
// In ConsumerWidget
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read (one-time)
    final useCase = ref.read(loginUseCaseProvider);
    
    // Watch (reactive)
    final authState = ref.watch(authNotifierProvider);
    
    return Container();
  }
}

// In callbacks
onPressed: () {
  final useCase = ref.read(loginUseCaseProvider);
  // Use useCase
}
```

### Best Practices

- Use `ref.read` for one-time access (callbacks, event handlers)
- Use `ref.watch` for reactive access (in build methods, providers)
- Use `Notifier` for complex state that changes over time
- Use `FutureProvider` for async data that loads once

See [Auth Provider Example](../api/features/auth/providers.md) for a complete example.

## Next Steps

- ✅ Review [Development Workflow](development-workflow.md) for Git and PR process
- ✅ Check [Common Patterns](../api/examples/common-patterns.md) for more examples
- ✅ See [Troubleshooting](troubleshooting.md) if you encounter issues

