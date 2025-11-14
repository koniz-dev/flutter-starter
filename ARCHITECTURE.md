# Clean Architecture - Flutter Project Structure

This Flutter project follows **Clean Architecture** principles with a **feature-first** organization. The architecture is designed to be scalable, maintainable, and testable.

## 📁 Project Structure

```
lib/
├── core/                    # Core layer - shared across all features
│   ├── constants/          # App-wide constants
│   │   ├── api_endpoints.dart
│   │   └── app_constants.dart
│   ├── config/             # Environment configuration
│   │   ├── app_config.dart
│   │   └── env_config.dart
│   ├── errors/             # Custom exceptions and failures
│   │   ├── exceptions.dart
│   │   └── failures.dart
│   ├── network/            # Network layer
│   │   ├── api_client.dart
│   │   └── interceptors/
│   │       ├── auth_interceptor.dart
│   │       └── logging_interceptor.dart
│   ├── storage/            # Local storage abstractions
│   │   └── storage_service.dart
│   └── utils/              # Helper functions and utilities
│       ├── result.dart
│       ├── date_formatter.dart
│       └── validators.dart
│
├── features/               # Features layer - organized by feature
│   └── auth/               # Example: Authentication feature
│       ├── data/           # Data layer
│       │   ├── datasources/
│       │   │   ├── auth_remote_datasource.dart
│       │   │   └── auth_local_datasource.dart
│       │   ├── models/
│       │   │   └── user_model.dart
│       │   └── repositories/
│       │       └── auth_repository_impl.dart
│       ├── domain/         # Domain layer (business logic)
│       │   ├── entities/
│       │   │   └── user.dart
│       │   ├── repositories/
│       │   │   └── auth_repository.dart
│       │   └── usecases/
│       │       └── login_usecase.dart
│       └── presentation/   # Presentation layer (UI)
│           ├── providers/
│           │   └── auth_provider.dart
│           ├── screens/
│           │   └── login_screen.dart
│           └── widgets/
│               └── auth_button.dart
│
└── shared/                 # Shared layer - reusable across features
    ├── widgets/            # Reusable UI components
    │   ├── loading_indicator.dart
    │   └── error_widget.dart
    ├── theme/              # App theme configuration
    │   ├── app_colors.dart
    │   ├── app_text_styles.dart
    │   └── app_theme.dart
    └── extensions/         # Dart extensions
        ├── string_extensions.dart
        ├── datetime_extensions.dart
        └── context_extensions.dart
```

## 🏗️ Architecture Layers

### 1. Core Layer (`lib/core/`)

The core layer contains infrastructure and shared utilities that are used across all features. It has no dependencies on other layers.

#### **constants/**
- **Purpose**: App-wide constants and configuration values
- **Files**:
  - `api_endpoints.dart`: API endpoint URLs
  - `app_constants.dart`: Application-wide constants (timeouts, pagination, storage keys)

#### **config/**
- **Purpose**: Environment configuration and app settings
- **Files**:
  - `app_config.dart`: Environment-based configuration (dev, staging, production)
  - `env_config.dart`: Environment variable loader

#### **errors/**
- **Purpose**: Custom exception and failure classes
- **Files**:
  - `exceptions.dart`: Exception classes (ServerException, NetworkException, etc.)
  - `failures.dart`: Failure classes for error handling

#### **network/**
- **Purpose**: HTTP client and network interceptors
- **Files**:
  - `api_client.dart`: Dio-based API client wrapper
  - `interceptors/`: Request/response interceptors (auth, logging)

#### **storage/**
- **Purpose**: Local storage abstractions
- **Files**:
  - `storage_service.dart`: Abstract storage interface and SharedPreferences implementation

#### **utils/**
- **Purpose**: Helper functions and utilities
- **Files**:
  - `result.dart`: Result type for handling success/failure states
  - `date_formatter.dart`: Date formatting utilities
  - `validators.dart`: Validation helper functions

### 2. Features Layer (`lib/features/`)

Each feature is self-contained and organized into three layers following Clean Architecture:

#### **data/** (Outer Layer)
- **Responsibility**: Data sources, models, and repository implementations
- **Components**:
  - `datasources/`: Remote and local data sources
  - `models/`: Data models (extend domain entities)
  - `repositories/`: Repository implementations

#### **domain/** (Inner Layer - Business Logic)
- **Responsibility**: Business logic, entities, and use cases
- **Components**:
  - `entities/`: Domain entities (pure Dart classes)
  - `repositories/`: Repository interfaces (abstract classes)
  - `usecases/`: Business logic use cases

#### **presentation/** (UI Layer)
- **Responsibility**: UI components, state management, and user interaction
- **Components**:
  - `providers/`: State management (Riverpod providers)
  - `screens/`: Full-screen UI components
  - `widgets/`: Feature-specific reusable widgets

### 3. Shared Layer (`lib/shared/`)

Reusable components that can be used across multiple features.

#### **widgets/**
- **Purpose**: Reusable UI components
- **Examples**: LoadingIndicator, AppErrorWidget

#### **theme/**
- **Purpose**: App-wide theming
- **Files**:
  - `app_colors.dart`: Color definitions
  - `app_text_styles.dart`: Text style definitions
  - `app_theme.dart`: Theme configuration (light/dark)

#### **extensions/**
- **Purpose**: Dart extension methods
- **Examples**: StringExtensions, DateTimeExtensions, ContextExtensions

## 🔄 Dependency Flow

The dependency rule in Clean Architecture states that dependencies should point inward:

```
Presentation → Domain ← Data
     ↓           ↑
   Shared    Core
```

- **Domain** has no dependencies (pure business logic)
- **Data** depends on **Domain** (implements domain interfaces)
- **Presentation** depends on **Domain** (uses use cases and entities)
- **Core** and **Shared** are independent utilities

## 📝 Key Principles

### 1. **Separation of Concerns**
- Each layer has a single, well-defined responsibility
- Business logic is isolated in the domain layer

### 2. **Dependency Inversion**
- Domain layer defines interfaces (repositories)
- Data layer implements these interfaces
- Presentation layer depends on abstractions, not implementations

### 3. **Feature-First Organization**
- Features are self-contained modules
- Easy to add, remove, or modify features independently
- Each feature can be developed and tested in isolation

### 4. **Testability**
- Domain layer is easily testable (no dependencies)
- Use cases are pure functions
- Data sources can be mocked for testing

## 🚀 Adding a New Feature

To add a new feature, follow this structure:

```
lib/features/your_feature/
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
└── presentation/
    ├── providers/
    ├── screens/
    └── widgets/
```

## 📦 Dependencies

- **flutter_riverpod**: State management
- **dio**: HTTP client
- **shared_preferences**: Local storage
- **equatable**: Value equality
- **intl**: Internationalization and date formatting

## 🔧 Configuration

### Environment Variables
Set environment variables when running the app:
```bash
flutter run --dart-define=ENVIRONMENT=production --dart-define=BASE_URL=https://api.example.com
```

### Storage Initialization
Initialize storage service in `main.dart`:
```dart
final storageService = StorageService();
await storageService.init();
```

## 📚 Best Practices

1. **Entities**: Pure Dart classes with no dependencies
2. **Use Cases**: Single responsibility, one use case per business action
3. **Models**: Extend entities and handle JSON serialization
4. **Repositories**: Implement domain interfaces, handle data transformation
5. **Providers**: Manage UI state, call use cases
6. **Error Handling**: Use Result type for explicit error handling

## 🧪 Testing Strategy

- **Domain**: Unit tests for entities, use cases, and repository interfaces
- **Data**: Unit tests for data sources and repository implementations (with mocks)
- **Presentation**: Widget tests for UI components, unit tests for providers

## 📖 Example Usage

See the `auth` feature for a complete example of:
- Domain entities and use cases
- Data sources (remote and local)
- Repository implementation
- State management with Riverpod
- UI screens and widgets

---

This architecture provides a solid foundation for building scalable Flutter applications with clear separation of concerns and maintainable code structure.

