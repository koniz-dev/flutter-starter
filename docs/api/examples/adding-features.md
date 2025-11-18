# Adding a New Feature

Step-by-step guide to adding a new feature following clean architecture.

## Overview

This guide walks through adding a complete feature from domain layer to UI, using the Products feature as an example.

---

## Step 1: Create Domain Layer

### 1.1 Create Entity

Create the domain entity representing your business object.

```dart
// lib/features/products/domain/entities/product.dart
import 'package:equatable/equatable.dart';

class Product extends Equatable {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    this.description,
  });

  final String id;
  final String name;
  final double price;
  final String? description;

  @override
  List<Object?> get props => [id, name, price, description];
}
```

### 1.2 Create Repository Interface

Define the repository interface in the domain layer.

```dart
// lib/features/products/domain/repositories/product_repository.dart
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/products/domain/entities/product.dart';

abstract class ProductRepository {
  /// Get all products
  Future<Result<List<Product>>> getProducts();

  /// Get product by ID
  Future<Result<Product>> getProductById(String id);

  /// Create a new product
  Future<Result<Product>> createProduct(Product product);

  /// Update an existing product
  Future<Result<Product>> updateProduct(Product product);

  /// Delete a product
  Future<Result<void>> deleteProduct(String id);
}
```

### 1.3 Create Use Cases

Create use cases for each business operation.

```dart
// lib/features/products/domain/usecases/get_products_usecase.dart
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/products/domain/entities/product.dart';
import 'package:flutter_starter/features/products/domain/repositories/product_repository.dart';

/// Use case for getting all products
class GetProductsUseCase {
  /// Creates a [GetProductsUseCase] with the given [repository]
  GetProductsUseCase(this.repository);

  /// Product repository for getting products
  final ProductRepository repository;

  /// Executes getting all products
  Future<Result<List<Product>>> call() async {
    return repository.getProducts();
  }
}
```

---

## Step 2: Create Data Layer

### 2.1 Create Model

Create the data model that extends the entity.

```dart
// lib/features/products/data/models/product_model.dart
import 'package:flutter_starter/features/products/domain/entities/product.dart';

class ProductModel extends Product {
  const ProductModel({
    required super.id,
    required super.name,
    required super.price,
    super.description,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'description': description,
    };
  }

  Product toEntity() {
    return Product(
      id: id,
      name: name,
      price: price,
      description: description,
    );
  }
}
```

### 2.2 Create Remote Data Source

Create the remote data source for API calls.

```dart
// lib/features/products/data/datasources/product_remote_datasource.dart
import 'package:flutter_starter/core/network/api_client.dart';
import 'package:flutter_starter/features/products/data/models/product_model.dart';

abstract class ProductRemoteDataSource {
  Future<List<ProductModel>> getProducts();
  Future<ProductModel> getProductById(String id);
  Future<ProductModel> createProduct(ProductModel product);
  Future<ProductModel> updateProduct(ProductModel product);
  Future<void> deleteProduct(String id);
}

class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  ProductRemoteDataSourceImpl(this.apiClient);

  final ApiClient apiClient;

  @override
  Future<List<ProductModel>> getProducts() async {
    final response = await apiClient.get('/products');
    final data = response.data as Map<String, dynamic>;
    final productsList = data['products'] as List;
    return productsList
        .map((json) => ProductModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ProductModel> getProductById(String id) async {
    final response = await apiClient.get('/products/$id');
    final data = response.data as Map<String, dynamic>;
    return ProductModel.fromJson(data);
  }

  // Implement other methods...
}
```

### 2.3 Create Local Data Source (Optional)

Create local data source for caching if needed.

```dart
// lib/features/products/data/datasources/product_local_datasource.dart
import 'package:flutter_starter/core/storage/storage_service.dart';
import 'package:flutter_starter/core/utils/json_helper.dart';
import 'package:flutter_starter/features/products/data/models/product_model.dart';

abstract class ProductLocalDataSource {
  Future<void> cacheProducts(List<ProductModel> products);
  Future<List<ProductModel>?> getCachedProducts();
  Future<void> clearCache();
}

class ProductLocalDataSourceImpl implements ProductLocalDataSource {
  ProductLocalDataSourceImpl(this.storageService);

  final StorageService storageService;
  static const String _cacheKey = 'cached_products';

  @override
  Future<void> cacheProducts(List<ProductModel> products) async {
    final productsJson = products.map((p) => p.toJson()).toList();
    final jsonString = JsonHelper.encode(productsJson);
    if (jsonString != null) {
      await storageService.setString(_cacheKey, jsonString);
    }
  }

  @override
  Future<List<ProductModel>?> getCachedProducts() async {
    final jsonString = await storageService.getString(_cacheKey);
    if (jsonString == null) return null;

    final productsList = JsonHelper.decodeList(jsonString);
    if (productsList == null) return null;

    return productsList
        .map((json) => ProductModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> clearCache() async {
    await storageService.remove(_cacheKey);
  }
}
```

### 2.4 Create Repository Implementation

Implement the repository interface.

```dart
// lib/features/products/data/repositories/product_repository_impl.dart
import 'package:flutter_starter/core/errors/exception_to_failure_mapper.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/products/data/datasources/product_local_datasource.dart';
import 'package:flutter_starter/features/products/data/datasources/product_remote_datasource.dart';
import 'package:flutter_starter/features/products/domain/entities/product.dart';
import 'package:flutter_starter/features/products/domain/repositories/product_repository.dart';

class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  final ProductRemoteDataSource remoteDataSource;
  final ProductLocalDataSource localDataSource;

  @override
  Future<Result<List<Product>>> getProducts() async {
    try {
      // Try to get from cache first
      final cachedProducts = await localDataSource.getCachedProducts();
      if (cachedProducts != null && cachedProducts.isNotEmpty) {
        return Success(cachedProducts.map((m) => m.toEntity()).toList());
      }

      // Fetch from remote
      final products = await remoteDataSource.getProducts();
      await localDataSource.cacheProducts(products);

      return Success(products.map((m) => m.toEntity()).toList());
    } on Exception catch (e) {
      return ResultFailure(ExceptionToFailureMapper.map(e));
    }
  }

  // Implement other methods...
}
```

---

## Step 3: Create Providers

Add providers to `lib/core/di/providers.dart`.

```dart
// Product Feature Providers
final productRemoteDataSourceProvider = Provider<ProductRemoteDataSource>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return ProductRemoteDataSourceImpl(apiClient);
});

final productLocalDataSourceProvider = Provider<ProductLocalDataSource>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return ProductLocalDataSourceImpl(storageService);
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final remoteDataSource = ref.read(productRemoteDataSourceProvider);
  final localDataSource = ref.watch(productLocalDataSourceProvider);
  return ProductRepositoryImpl(
    remoteDataSource: remoteDataSource,
    localDataSource: localDataSource,
  );
});

final getProductsUseCaseProvider = Provider<GetProductsUseCase>((ref) {
  final repository = ref.watch(productRepositoryProvider);
  return GetProductsUseCase(repository);
});
```

---

## Step 4: Use in UI

Create UI components that use the providers.

```dart
class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(_productsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      body: productsAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return const Center(child: Text('No products found'));
          }
          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return ListTile(
                title: Text(product.name),
                subtitle: Text('\$${product.price}'),
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

final _productsProvider = FutureProvider<List<Product>>((ref) async {
  final useCase = ref.read(getProductsUseCaseProvider);
  final result = await useCase();
  return result.when(
    success: (products) => products,
    failureCallback: (failure) => throw failure,
  );
});
```

---

## Checklist

- [ ] Create domain entity
- [ ] Create repository interface
- [ ] Create use cases
- [ ] Create data model
- [ ] Create remote data source
- [ ] Create local data source (if needed)
- [ ] Create repository implementation
- [ ] Add providers
- [ ] Create UI components
- [ ] Write tests

---

## Related APIs

- [Common Patterns](common-patterns.md) - Common usage patterns
- [API Integration](api-integration.md) - API integration patterns
- [Auth - Repositories](../features/auth/repositories.md) - Example repository

