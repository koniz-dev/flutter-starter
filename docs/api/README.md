# API Documentation

Complete API reference for the Flutter Starter project.

## Overview

This documentation provides comprehensive reference for all public APIs in the Flutter Starter project, organized by architectural layer and component type.

## Documentation Structure

### Core APIs

- **[Errors](core/errors.md)** - Exception and Failure types for error handling
- **[Network](core/network.md)** - HTTP client and interceptors
- **[Storage](core/storage.md)** - Storage services (regular and secure)
- **[Utils](core/utils.md)** - Utility classes (Result, JsonHelper, DateFormatter, Validators)

### Feature APIs

- **[Auth - Repositories](features/auth/repositories.md)** - Authentication repository interfaces
- **[Auth - Use Cases](features/auth/usecases.md)** - Authentication use cases
- **[Auth - Models](features/auth/models.md)** - Authentication data models
- **[Auth - Providers](features/auth/providers.md)** - Authentication state management providers

### Examples

- **[Adding Features](examples/adding-features.md)** - Step-by-step guide to adding new features
- **[API Integration](examples/api-integration.md)** - Patterns for API integration
- **[Common Patterns](examples/common-patterns.md)** - Common usage patterns and best practices

## Quick Start

### For New Developers

1. Start with [Common Patterns](examples/common-patterns.md) to understand basic usage
2. Review [API Integration](examples/api-integration.md) for integration patterns
3. Refer to specific API documentation as needed

### For Adding New Features

1. Follow the guide in [Adding Features](examples/adding-features.md)
2. Reference existing feature APIs (e.g., [Auth](features/auth/)) as examples
3. Use [Common Patterns](examples/common-patterns.md) for best practices

### For API Reference

1. Navigate to the appropriate section:
   - **Core APIs** for infrastructure components
   - **Feature APIs** for domain-specific APIs
2. Find the specific class or method you need
3. Review the examples and usage patterns

## Key Concepts

### Result Pattern

All repository and use case methods return `Result<T>` for type-safe error handling:

```dart
final result = await loginUseCase('user@example.com', 'password');
result.when(
  success: (user) => handleSuccess(user),
  failureCallback: (failure) => handleFailure(failure),
);
```

See [Utils - Result](core/utils.md#result) for details.

### Dependency Injection

All dependencies are provided via Riverpod providers:

```dart
// Access in widgets
final useCase = ref.read(loginUseCaseProvider);

// Access in providers
final repository = ref.watch(authRepositoryProvider);
```

See [Auth - Providers](features/auth/providers.md) for details.

### Error Handling

Errors are represented as typed `Failure` objects wrapped in `ResultFailure`:

```dart
result.when(
  success: (data) => ...,
  failureCallback: (failure) {
    if (failure is AuthFailure) {
      // Handle auth error
    } else if (failure is NetworkFailure) {
      // Handle network error
    }
  },
);
```

See [Errors](core/errors.md) for details.

## Architecture Layers

### Domain Layer

Business logic and entities, independent of external frameworks.

**Key Components:**
- Repository interfaces
- Use cases
- Entities

**Location:** `lib/features/*/domain/`

### Data Layer

Data sources and repository implementations.

**Key Components:**
- Remote data sources
- Local data sources
- Repository implementations
- Models

**Location:** `lib/features/*/data/`

### Core Layer

Infrastructure components used across the application.

**Key Components:**
- Network (ApiClient, Interceptors)
- Storage (StorageService, SecureStorageService)
- Configuration (AppConfig, EnvConfig)
- Utilities (Result, JsonHelper, Validators, DateFormatter)
- Error Handling (Failures, Exceptions)

**Location:** `lib/core/`

### Shared Layer

Reusable components used across features.

**Key Components:**
- Extensions (Context, String, DateTime)

**Location:** `lib/shared/`

## Related Documentation

- [Architecture Overview](../architecture/OVERVIEW.md) - Architectural principles and patterns
- [Project Structure](../architecture/STRUCTURE.md) - File organization
- [README.md](../../README.md) - Project setup and configuration

## Contributing

When adding new APIs:

1. Add comprehensive DartDoc comments to all public classes and methods
2. Include usage examples in documentation
3. Update this documentation if adding new layers or major components
4. Follow existing patterns and conventions

