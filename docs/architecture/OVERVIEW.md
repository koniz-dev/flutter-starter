# Architecture Overview

**Last Updated:** November 15, 2025

This document explains the architectural principles and patterns used in this Flutter starter.

> **Note**: For complete file structure and reference, see [Project Structure](STRUCTURE.md)

## Contents

- [Dependency Flow](#dependency-flow)
- [Key Principles](#key-principles)
- [Adding New Features](#adding-new-features)
- [Configuration](#configuration)
- [Best Practices](#best-practices)
- [Error Handling](#error-handling)
- [Testing Strategy](#testing-strategy)

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

## 🚀 Adding New Features

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

## ⚠️ Error Handling

The project uses a comprehensive error handling strategy with typed failures and exception-to-failure mapping. For detailed information, see [Error Handling Strategy](error-handling.md).

### Quick Overview

1. **Network errors** (`DioException`) are automatically mapped to domain exceptions by `ErrorInterceptor`
2. **Domain exceptions** (`AppException`) are mapped to typed failures in repositories
3. **Typed failures** (`Failure`) are displayed to users via state management
4. **Error codes** are preserved for programmatic handling
5. **Error messages** are user-friendly and contextual

### Key Components

- `DioExceptionMapper` - Maps DioException to AppException
- `ExceptionToFailureMapper` - Maps AppException to Failure
- `ErrorInterceptor` - Automatically handles network errors
- `Result<T>` - Type-safe success/failure handling

---

This architecture provides a solid foundation for building scalable Flutter applications with clear separation of concerns and maintainable code structure.

