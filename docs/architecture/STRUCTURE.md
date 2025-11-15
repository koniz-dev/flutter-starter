# Project Structure - Quick Reference

**Last Updated:** November 15, 2025

This is a quick reference guide for file locations and structure.

> **Note**: For architectural principles, see [Architecture Overview](OVERVIEW.md)

## Contents

- [Complete File Structure](#complete-file-structure)
- [Layer Responsibilities](#layer-responsibilities)
- [Adding New Features](#adding-new-features)
- [Key Files](#key-files)
- [Finding Files](#finding-files)

## Complete File Structure

```
lib/
├── main.dart
│
├── core/                           # Core infrastructure layer
│   ├── constants/
│   │   ├── api_endpoints.dart      # API endpoint URLs
│   │   └── app_constants.dart      # App-wide constants
│   ├── config/
│   │   ├── app_config.dart         # Environment configuration
│   │   └── env_config.dart         # Environment variable loader
│   ├── errors/
│   │   ├── exceptions.dart         # Exception classes
│   │   └── failures.dart           # Failure classes
│   ├── network/
│   │   ├── api_client.dart         # HTTP client wrapper
│   │   └── interceptors/
│   │       ├── auth_interceptor.dart    # Auth token interceptor
│   │       └── logging_interceptor.dart # Request/response logging
│   ├── storage/
│   │   └── storage_service.dart    # Local storage abstraction
│   └── utils/
│       ├── result.dart             # Result type for error handling
│       ├── date_formatter.dart     # Date formatting utilities
│       └── validators.dart         # Validation helpers
│
├── features/                       # Feature modules
│   └── auth/                       # Authentication feature (example)
│       ├── data/                   # Data layer
│       │   ├── datasources/
│       │   │   ├── auth_remote_datasource.dart  # Remote API calls
│       │   │   └── auth_local_datasource.dart    # Local cache
│       │   ├── models/
│       │   │   └── user_model.dart              # Data model
│       │   └── repositories/
│       │       └── auth_repository_impl.dart     # Repository implementation
│       ├── domain/                 # Domain layer (business logic)
│       │   ├── entities/
│       │   │   └── user.dart                    # Domain entity
│       │   ├── repositories/
│       │   │   └── auth_repository.dart          # Repository interface
│       │   └── usecases/
│       │       └── login_usecase.dart            # Login use case
│       └── presentation/           # Presentation layer (UI)
│           ├── providers/
│           │   └── auth_provider.dart            # State management
│           ├── screens/
│           │   └── login_screen.dart             # Login screen
│           └── widgets/
│               └── auth_button.dart              # Feature widgets
│
└── shared/                         # Shared utilities
    ├── widgets/
    │   ├── loading_indicator.dart  # Reusable loading widget
    │   └── error_widget.dart       # Reusable error widget
    ├── theme/
    │   ├── app_colors.dart         # Color definitions
    │   ├── app_text_styles.dart    # Text style definitions
    │   └── app_theme.dart          # Theme configuration
    └── extensions/
        ├── string_extensions.dart  # String extension methods
        ├── datetime_extensions.dart # DateTime extension methods
        └── context_extensions.dart  # BuildContext extension methods
```

## Layer Responsibilities

**Core Layer** - Infrastructure & shared utilities (network, storage, config)  
**Features Layer** - Feature modules with data/domain/presentation structure  
**Shared Layer** - Reusable UI components & extensions

> See [Architecture Overview](OVERVIEW.md#-architecture-layers) for detailed layer explanations.

## Adding New Features

See [Adding New Features](OVERVIEW.md#-adding-new-features) in Architecture Overview for detailed instructions.

**Quick Reference**:
- Create `lib/features/{feature_name}/`
- Follow `auth` feature structure as template

## Key Files

### Entry Point
- `lib/main.dart` - Application entry point

### Core Files
- `core/network/api_client.dart` - HTTP client setup
- `core/storage/storage_service.dart` - Local storage
- `core/utils/result.dart` - Error handling type

### Example Feature (Auth)
- `features/auth/domain/entities/user.dart` - Business entity
- `features/auth/domain/usecases/login_usecase.dart` - Business logic
- `features/auth/data/repositories/auth_repository_impl.dart` - Data implementation
- `features/auth/presentation/providers/auth_provider.dart` - State management

### Shared Files
- `shared/theme/app_theme.dart` - App theming
- `shared/widgets/loading_indicator.dart` - Reusable widgets

## Finding Files

### By Type

**Constants & Configuration**
- `core/constants/` - App-wide constants
- `core/config/` - Environment configuration

**Network & API**
- `core/network/api_client.dart` - HTTP client
- `core/network/interceptors/` - Request interceptors
- `features/{feature}/data/datasources/` - API data sources

**Storage**
- `core/storage/storage_service.dart` - Storage abstraction
- `features/{feature}/data/datasources/*_local_datasource.dart` - Local cache

**Business Logic**
- `features/{feature}/domain/entities/` - Domain entities
- `features/{feature}/domain/usecases/` - Business logic
- `features/{feature}/domain/repositories/` - Repository interfaces

**Data Models**
- `features/{feature}/data/models/` - Data models
- `features/{feature}/data/repositories/` - Repository implementations

**UI Components**
- `features/{feature}/presentation/screens/` - Full screens
- `features/{feature}/presentation/widgets/` - Feature widgets
- `shared/widgets/` - Reusable widgets

**State Management**
- `features/{feature}/presentation/providers/` - Riverpod providers

**Theme & Styling**
- `shared/theme/` - App theme, colors, text styles

**Utilities**
- `core/utils/` - Helper functions
- `shared/extensions/` - Dart extensions

### By Feature

Navigate to `lib/features/{feature_name}/` and look for:
- `data/` - Data sources, models, repository implementations
- `domain/` - Entities, use cases, repository interfaces
- `presentation/` - Providers, screens, widgets

