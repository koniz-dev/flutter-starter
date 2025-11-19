# Understanding the Codebase

This guide explains the architecture, code organization, and key patterns used in the Flutter Starter project.

## Architecture Overview

This project follows **Clean Architecture** principles with clear separation of concerns:

```
┌─────────────────────────────────────┐
│      Presentation Layer (UI)        │
│  - Screens, Widgets, Providers      │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│         Domain Layer                │
│ - Entities, Use Cases, Repositories │
│ - Business Logic (Framework-free)   │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│         Data Layer                  │
│ - Models, Data Sources, Repository  │
│ - Implementations                   │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│         Core Layer                  │
│  - Network, Storage, Config, Utils  │
└─────────────────────────────────────┘
```

**Key Principles:**
- **Dependency Inversion**: Inner layers don't depend on outer layers
- **Separation of Concerns**: Each layer has a specific responsibility
- **Testability**: Business logic is independent of frameworks
- **Maintainability**: Clear boundaries make changes easier

For detailed architecture documentation, see:
- [Architecture Documentation](../architecture/README.md) - Complete architecture documentation
- [Architecture Overview](../architecture/overview.md) - Why Clean Architecture, benefits, trade-offs
- [Design Decisions](../architecture/design-decisions.md) - Technical decisions and rationale
- [API Documentation](../api/README.md)

## Code Organization

```
lib/
├── core/                    # Infrastructure components
│   ├── config/             # Configuration (AppConfig, EnvConfig)
│   ├── constants/          # App-wide constants
│   ├── di/                 # Dependency injection (providers)
│   ├── errors/             # Error handling (Failures, Exceptions)
│   ├── network/            # HTTP client, interceptors
│   ├── storage/            # Storage services (regular & secure)
│   └── utils/              # Utilities (Result, JsonHelper, Validators)
│
├── features/               # Feature modules
│   └── auth/              # Example: Authentication feature
│       ├── data/          # Data layer
│       │   ├── datasources/    # Remote & local data sources
│       │   ├── models/         # Data models
│       │   └── repositories/   # Repository implementations
│       ├── domain/        # Domain layer
│       │   ├── entities/      # Business entities
│       │   ├── repositories/  # Repository interfaces
│       │   └── usecases/      # Business logic (use cases)
│       └── presentation/ # Presentation layer
│           └── providers/     # State management (Riverpod)
│
├── shared/                # Shared components
│   ├── extensions/        # Extension methods
│   └── theme/            # App theme
│
└── main.dart              # App entry point

docs/
├── api/                   # API documentation
├── architecture/          # Architecture docs (if available)
└── guides/               # Guides (this file)
```

## Key Patterns

### 1. Result Pattern

All repository and use case methods return `Result<T>` for type-safe error handling:

```dart
final result = await loginUseCase('user@example.com', 'password');
result.when(
  success: (user) => handleSuccess(user),
  failureCallback: (failure) => handleFailure(failure),
);
```

**Benefits:**
- Type-safe error handling
- No exceptions for business logic errors
- Explicit error types (AuthFailure, NetworkFailure, etc.)

See [Common Patterns](../api/examples/common-patterns.md#result-pattern) for more details.

### 2. Dependency Injection with Riverpod

All dependencies are provided via Riverpod providers:

```dart
// In widgets
final useCase = ref.read(loginUseCaseProvider);

// In providers
final repository = ref.watch(authRepositoryProvider);
```

**Key Providers:**
- `ref.read`: One-time access (e.g., in callbacks)
- `ref.watch`: Reactive access (rebuilds when provider changes)

See [Dependency Injection Pattern](../api/examples/common-patterns.md#dependency-injection-pattern) for more details.

### 3. Clean Architecture Layers

**Domain Layer** (`lib/features/*/domain/`):
- Entities: Business objects
- Repository interfaces: Data contracts
- Use cases: Business logic

**Data Layer** (`lib/features/*/data/`):
- Models: Data transfer objects
- Data sources: API and local storage
- Repository implementations: Coordinate data sources

**Presentation Layer** (`lib/features/*/presentation/`):
- Providers: State management (Riverpod)
- Screens/Widgets: UI components

### 4. Error Handling

Errors are represented as typed `Failure` objects:

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

See [Errors API](../api/core/errors.md) for all error types.

## Where to Find Things

| What You Need | Where to Look |
|---------------|---------------|
| **API Documentation** | `docs/api/` |
| **Configuration** | `lib/core/config/` |
| **Network/HTTP** | `lib/core/network/` |
| **Storage** | `lib/core/storage/` |
| **Error Types** | `lib/core/errors/` |
| **Utilities** | `lib/core/utils/` |
| **Feature Code** | `lib/features/<feature-name>/` |
| **Shared Components** | `lib/shared/` |
| **Dependency Injection** | `lib/core/di/providers.dart` |
| **Tests** | `test/` |
| **Examples** | `docs/api/examples/` |

## Next Steps

- ✅ Learn how to [add features and screens](../features/common-tasks.md)
- ✅ Review [Common Patterns](../api/examples/common-patterns.md)
- ✅ Explore existing features (e.g., `lib/features/auth/`)

