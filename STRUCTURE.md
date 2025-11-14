# Project Structure Quick Reference

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

### Core Layer
- **Purpose**: Infrastructure and shared utilities
- **Dependencies**: None (independent)
- **Contains**: Constants, config, errors, network, storage, utils

### Features Layer
- **Purpose**: Feature-specific code organized by feature
- **Structure**: Each feature has `data/`, `domain/`, `presentation/`
- **Dependencies**: Features depend on Core and Shared

### Shared Layer
- **Purpose**: Reusable components across features
- **Contains**: Widgets, theme, extensions
- **Dependencies**: Core (for utilities)

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

## Adding New Features

1. Create feature folder: `lib/features/your_feature/`
2. Add three subfolders: `data/`, `domain/`, `presentation/`
3. Follow the same structure as `auth` feature
4. Implement domain layer first (entities, repositories, use cases)
5. Then data layer (models, data sources, repository implementation)
6. Finally presentation layer (providers, screens, widgets)

## Dependencies

- `flutter_riverpod` - State management
- `dio` - HTTP client
- `shared_preferences` - Local storage
- `equatable` - Value equality
- `intl` - Internationalization

See `ARCHITECTURE.md` for detailed documentation.

