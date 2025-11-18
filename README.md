# 🚀 Flutter Starter

A production-ready Flutter starter project with **Clean Architecture**, enterprise-grade configuration management, and comprehensive developer tooling.

[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## ✨ Features

### 🏗️ Architecture & Code Quality
- ✅ **Clean Architecture** - Separation of concerns with Domain, Data, and Presentation layers
- ✅ **State Management** - Riverpod for reactive state management
- ✅ **Code Generation** - Freezed for immutable classes and JSON serialization
- ✅ **Linting** - Very Good Analysis for comprehensive code quality checks
- ✅ **Testing** - Mocktail for unit testing with comprehensive test coverage

### ⚙️ Configuration & Environment
- ✅ **Multi-Environment Support** - Development, Staging, Production
- ✅ **Flexible Configuration** - `.env` files for local dev, `--dart-define` for CI/CD
- ✅ **Feature Flags** - Local and remote (Firebase Remote Config) feature flags
- ✅ **Environment-Aware Defaults** - Smart defaults based on environment
- ✅ **Type-Safe Configuration** - Typed getters with fallback chain

### 🌐 Internationalization
- ✅ **Multi-Language Support** - Flutter localization with ARB files
- ✅ **RTL Support** - Right-to-left language support
- ✅ **Locale Persistence** - Save and restore user language preference

### 🔐 Security & Storage
- ✅ **Secure Storage** - Flutter Secure Storage for sensitive data
- ✅ **Shared Preferences** - Simple key-value storage for non-sensitive data
- ✅ **Error Handling** - Comprehensive error handling with custom exceptions

### 🌐 Network Layer
- ✅ **HTTP Client** - Dio with interceptors support
- ✅ **Configurable Timeouts** - Environment-based timeout configuration
- ✅ **Request/Response Logging** - Debug-friendly HTTP logging

### 🎨 UI & UX
- ✅ **Material Design** - Material 3 theme support
- ✅ **Dark Mode** - Built-in dark theme support
- ✅ **Accessibility** - Semantic labels and accessibility support
- ✅ **Responsive Design** - Adaptive layouts for different screen sizes

### 🚀 Deployment & CI/CD
- ✅ **Multi-Platform** - Android, iOS, Web, Linux, macOS, Windows support
- ✅ **CI/CD Ready** - GitHub Actions workflows included
- ✅ **Version Management** - Automated version bumping scripts
- ✅ **Fastlane Integration** - iOS and Android deployment automation

### 📚 Documentation
- ✅ **Comprehensive Docs** - Architecture, guides, API documentation
- ✅ **Migration Guides** - From MVC, GetX, and other architectures
- ✅ **Best Practices** - Code examples and patterns

## 🛠️ Tech Stack

### Core Dependencies
- **Flutter** - UI framework
- **Riverpod** - State management
- **Dio** - HTTP client
- **Freezed** - Code generation for immutable classes
- **Equatable** - Value equality comparison

### Firebase
- **Firebase Core** - Firebase initialization
- **Firebase Remote Config** - Remote feature flags

### Storage
- **flutter_secure_storage** - Secure storage for sensitive data
- **shared_preferences** - Simple key-value storage

### Localization
- **flutter_localizations** - Flutter localization support
- **intl** - Internationalization utilities

### Development Tools
- **build_runner** - Code generation runner
- **very_good_analysis** - Linting rules
- **mocktail** - Testing and mocking

## 📁 Project Structure

```
lib/
├── core/                    # Core infrastructure
│   ├── config/             # Configuration system
│   ├── constants/          # App constants
│   ├── di/                 # Dependency injection (Riverpod providers)
│   ├── errors/             # Error handling
│   ├── feature_flags/      # Feature flags infrastructure
│   ├── localization/       # Localization service
│   ├── network/            # Network layer (Dio setup)
│   ├── storage/            # Storage services
│   └── utils/              # Utility functions
│
├── features/                # Feature modules (Clean Architecture)
│   ├── auth/               # Authentication feature example
│   │   ├── data/          # Data layer (models, data sources, repositories)
│   │   ├── domain/        # Domain layer (entities, use cases, repository interfaces)
│   │   └── presentation/  # Presentation layer (screens, widgets, providers)
│   └── feature_flags/      # Feature flags feature
│       └── presentation/   # Feature flags UI
│
├── shared/                  # Shared resources
│   ├── accessibility/      # Accessibility utilities
│   ├── extensions/         # Dart extensions
│   ├── theme/              # App theme configuration
│   └── widgets/            # Reusable widgets
│
├── l10n/                   # Localization files (generated)
└── main.dart               # App entry point
```

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)
- Android Studio / VS Code with Flutter extensions
- Xcode (for iOS development on macOS)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd flutter_starter
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate code** (Freezed, JSON serialization)
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Set up environment configuration**
   ```bash
   # Copy the example environment file
   cp .env.example .env
   
   # Edit .env with your configuration
   # See Configuration System section below
   ```

5. **Run the app**
   ```bash
   flutter run
   ```

### First Steps

1. **Configure your environment** - See [Configuration System](#-configuration-system) below
2. **Set up Firebase** (optional) - For remote feature flags
3. **Customize the theme** - Edit `lib/shared/theme/app_theme.dart`
4. **Add your first feature** - Follow the pattern in `lib/features/auth/`
5. **Read the documentation** - Check out `docs/` folder for detailed guides

## ⚙️ Configuration System

This project includes a production-ready, multi-environment configuration system that supports:

- **Local Development**: `.env` files for easy local configuration
- **CI/CD**: `--dart-define` flags for build-time configuration
- **Fallback Chain**: `.env` → `--dart-define` → defaults
- **Environment-Aware Defaults**: Different configurations per environment
- **Feature Flags**: Enable/disable features per environment
- **Network Configuration**: Timeout settings for API calls
- **Debug Utilities**: Tools for inspecting configuration

### Architecture

The configuration system consists of two main classes:

1. **`EnvConfig`** (`lib/core/config/env_config.dart`): Low-level environment variable loader
   - Loads from `.env` files using `flutter_dotenv`
   - Reads from `--dart-define` flags
   - Provides fallback chain: `.env` → `--dart-define` → defaults

2. **`AppConfig`** (`lib/core/config/app_config.dart`): High-level application configuration
   - Uses `EnvConfig` to get values
   - Provides typed getters (String, bool, int)
   - Environment-aware defaults
   - Feature flags
   - Network timeout configuration
   - Debug utilities

### Setup

#### 1. Create `.env` file for local development

```bash
# Copy the example file
cp .env.example .env

# Edit .env with your values
# The .env file is gitignored and won't be committed
```

#### 2. Configure your environment variables

Edit `.env` with your configuration:

```env
ENVIRONMENT=development
BASE_URL=http://localhost:3000
ENABLE_LOGGING=true
ENABLE_ANALYTICS=false
```

### Usage Examples

#### Local Development (using `.env` file)

1. Create `.env` file from `.env.example`
2. Fill in your values
3. Run the app normally:

```bash
flutter run
```

The app will automatically load values from `.env`.

#### Staging Build (using `--dart-define`)

For CI/CD or when you don't want to use `.env` files:

```bash
flutter run \
  --dart-define=ENVIRONMENT=staging \
  --dart-define=BASE_URL=https://api-staging.example.com \
  --dart-define=ENABLE_ANALYTICS=true
```

#### Production Build (using `--dart-define`)

```bash
flutter build apk \
  --dart-define=ENVIRONMENT=production \
  --dart-define=BASE_URL=https://api.example.com \
  --dart-define=ENABLE_ANALYTICS=true \
  --dart-define=ENABLE_CRASH_REPORTING=true
```

### Using Configuration in Code

#### Basic Usage

```dart
import 'package:flutter_starter/core/config/app_config.dart';

// Get environment
final env = AppConfig.environment; // 'development', 'staging', or 'production'

// Check environment
if (AppConfig.isDevelopment) {
  // Development-specific code
}

// Get API base URL
final baseUrl = AppConfig.baseUrl;

// Check feature flags
if (AppConfig.enableLogging) {
  logger.info('App started');
}

if (AppConfig.enableAnalytics) {
  analytics.trackEvent('app_opened');
}
```

#### Network Configuration

```dart
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:dio/dio.dart';

final dio = Dio(
  BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: Duration(seconds: AppConfig.apiConnectTimeout),
    receiveTimeout: Duration(seconds: AppConfig.apiReceiveTimeout),
    sendTimeout: Duration(seconds: AppConfig.apiSendTimeout),
  ),
);
```

#### Debug Utilities

```dart
import 'package:flutter_starter/core/config/app_config.dart';

// Print configuration to console (only in debug mode)
AppConfig.printConfig();

// Get configuration as a map
final config = AppConfig.getDebugInfo();
print(config);
```

### Available Configuration Options

#### Environment Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `ENVIRONMENT` | String | `development` | Environment name: `development`, `staging`, or `production` |
| `BASE_URL` | String | Environment-aware | API base URL (see defaults below) |
| `API_TIMEOUT` | int | `30` | API timeout in seconds |
| `API_CONNECT_TIMEOUT` | int | `10` | API connect timeout in seconds |
| `API_RECEIVE_TIMEOUT` | int | `30` | API receive timeout in seconds |
| `API_SEND_TIMEOUT` | int | `30` | API send timeout in seconds |
| `ENABLE_LOGGING` | bool | Environment-aware | Enable logging (default: true in dev/staging) |
| `ENABLE_ANALYTICS` | bool | Environment-aware | Enable analytics (default: true in staging/prod) |
| `ENABLE_CRASH_REPORTING` | bool | Environment-aware | Enable crash reporting (default: true in staging/prod) |
| `ENABLE_PERFORMANCE_MONITORING` | bool | Environment-aware | Enable performance monitoring (default: true in staging/prod) |
| `ENABLE_DEBUG_FEATURES` | bool | Environment-aware | Enable debug features (default: true in dev) |
| `ENABLE_HTTP_LOGGING` | bool | Environment-aware | Enable HTTP request/response logging (default: true in dev) |
| `APP_VERSION` | String | `1.0.0` | App version |
| `APP_BUILD_NUMBER` | String | `1` | App build number |

#### Environment-Aware Defaults

**BASE_URL defaults:**
- Development: `http://localhost:3000`
- Staging: `https://api-staging.example.com`
- Production: `https://api.example.com`

**Feature Flag defaults:**
- Logging: Enabled in `development` and `staging`
- Analytics: Enabled in `staging` and `production`
- Crash Reporting: Enabled in `staging` and `production`
- Performance Monitoring: Enabled in `staging` and `production`
- Debug Features: Enabled in `development` only
- HTTP Logging: Enabled in `development` only

### Best Practices

1. **Never commit `.env` files**: They contain sensitive information and are gitignored
2. **Use `.env.example` as a template**: Commit this file with placeholder values
3. **Use `.env` for local development**: Easy to change values without rebuilding
4. **Use `--dart-define` for CI/CD**: More secure and doesn't require file management
5. **Set environment-specific defaults**: Let the system handle defaults based on environment
6. **Use feature flags**: Enable/disable features per environment without code changes

### Troubleshooting

#### Configuration not loading

1. Ensure `EnvConfig.load()` is called in `main()` before `runApp()`
2. Check that `.env` file exists in the project root
3. Verify `pubspec.yaml` includes `.env` in assets
4. Run `flutter pub get` after adding `flutter_dotenv`

#### Values not updating

1. Hot reload doesn't reload environment variables - do a full restart
2. For `--dart-define` values, rebuild the app
3. Check that you're using the correct variable name (case-sensitive)

#### Debug configuration

Use `AppConfig.printConfig()` in debug mode to see all configuration values:

```dart
if (AppConfig.isDebugMode) {
  AppConfig.printConfig();
}
```

This will print all configuration values to the console, helping you verify what values are being used.

## 🧪 Testing

### Run Tests

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/features/auth/domain/usecases/login_test.dart
```

### Test Structure

Tests follow the same structure as the source code:
- Unit tests for use cases and utilities
- Widget tests for UI components
- Integration tests for end-to-end flows

## 🏗️ Building

### Android

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# App Bundle (for Play Store)
flutter build appbundle --release
```

### iOS

```bash
# Debug
flutter build ios --debug

# Release
flutter build ios --release
```

### Web

```bash
# Debug
flutter build web --debug

# Release
flutter build web --release
```

## 📚 Documentation

### Architecture

- **[Architecture Overview](docs/architecture/OVERVIEW.md)** - Principles, patterns, best practices
- **[Project Structure](docs/architecture/STRUCTURE.md)** - File organization reference

### Guides

- **[Getting Started](docs/guides/getting-started.md)** - Step-by-step setup guide
- **[Understanding the Codebase](docs/guides/understanding-codebase.md)** - Architecture and patterns
- **[Common Tasks](docs/guides/common-tasks.md)** - Frequently performed tasks
- **[Routing Guide](docs/guides/routing.md)** - GoRouter navigation and deep linking
- **[Adding Features](docs/api/examples/adding-features.md)** - How to add new features

### Migration Guides

- **[From MVC to Clean Architecture](docs/guides/migration/from-mvc-to-clean-architecture.md)**
- **[From GetX to This Setup](docs/guides/migration/from-getx-to-this-setup.md)**
- **[Customization Guide](docs/guides/migration/customization-guide.md)**

### Features

- **[Feature Flags](docs/features/feature-flags.md)** - Feature flags system documentation
- **[Localization](docs/guides/accessibility/README.md)** - i18n setup and usage

### Deployment

- **[Deployment Guide](docs/deployment/deployment.md)** - Complete deployment documentation
- **[Quick Start](docs/deployment/quick-start.md)** - Get started in 5 minutes
- **[Android Deployment](docs/deployment/android-deployment.md)** - Android-specific guide
- **[iOS Deployment](docs/deployment/ios-deployment.md)** - iOS-specific guide
- **[Web Deployment](docs/deployment/web-deployment.md)** - Web-specific guide
- **[Release Process](docs/deployment/release-process.md)** - Version management and releases
- **[Monitoring & Analytics](docs/deployment/monitoring-analytics.md)** - Crashlytics and analytics setup

### API Documentation

- **[API Overview](docs/api/README.md)** - API documentation index
- **[Examples](docs/api/examples/)** - Code examples and patterns

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style

- Follow the existing code style
- Run `flutter analyze` before committing
- Ensure all tests pass
- Update documentation as needed

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Flutter](https://flutter.dev) - The framework
- [Riverpod](https://riverpod.dev) - State management
- [Very Good Ventures](https://verygood.ventures) - Linting rules and best practices
- [Freezed](https://pub.dev/packages/freezed) - Code generation

## 📞 Support

For questions, issues, or contributions, please open an issue on GitHub.

---

**Made with ❤️ using Flutter**
