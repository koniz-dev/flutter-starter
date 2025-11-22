# Getting Started

This guide will help you set up your development environment and get the Flutter Starter project running.

## Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK**: Version 3.0.0 or higher
  - Check your version: `flutter --version`
  - Install/update: [Flutter Installation Guide](https://docs.flutter.dev/get-started/install)
  
- **Dart SDK**: Version 3.0.0 or higher (included with Flutter)

- **IDE**: Choose one of the following:
  - **VS Code** (recommended): Install Flutter and Dart extensions
  - **Android Studio**: Install Flutter and Dart plugins
  - **IntelliJ IDEA**: Install Flutter and Dart plugins

- **Platform-specific tools** (for your target platforms):
  - **Android**: Android Studio with Android SDK
  - **iOS**: Xcode (macOS only)
  - **Web**: Chrome (for web development)

- **Git**: For version control

- **Code Generation Tools**:
  - `build_runner` (installed via pubspec.yaml)
  - `freezed` (installed via pubspec.yaml)
  - `json_serializable` (installed via pubspec.yaml)

## Setup Instructions

### 1. Clone the Repository

```bash
git clone <repository-url>
cd flutter_starter
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Set Up Environment Configuration

The project uses a flexible configuration system that supports multiple environments.

**Option A: Using `.env` file (Recommended for local development)**

```bash
# Copy the example file
cp .env.example .env

# Edit .env with your local configuration
# The .env file is gitignored and won't be committed
```

**Option B: Using `--dart-define` flags (For CI/CD or when not using .env)**

You can pass configuration via command-line flags (see [Environment Configuration](#environment-configuration) below).

### 4. Generate Code

The project uses code generation for models and serialization. Run:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

**Note**: Run this command whenever you:
- Add or modify `@freezed` classes
- Add or modify `@JsonSerializable` classes
- Change model structures

**Watch mode** (for development):
```bash
flutter pub run build_runner watch --delete-conflicting-outputs
```

### 5. Verify Setup

```bash
# Check Flutter installation
flutter doctor

# Run tests to verify everything works
flutter test

# Analyze code
flutter analyze
```

## Running the App

### Development Mode

```bash
# Run on connected device/emulator
flutter run

# Run on specific device
flutter devices  # List available devices
flutter run -d <device-id>

# Run in release mode (for performance testing)
flutter run --release
```

### Platform-Specific

```bash
# Android
flutter run -d android

# iOS (macOS only)
flutter run -d ios

# Web
flutter run -d chrome

# Desktop (Linux/macOS/Windows)
flutter run -d linux
flutter run -d macos
flutter run -d windows
```

### Hot Reload and Hot Restart

- **Hot Reload** (`r` in terminal or `Ctrl+S` / `Cmd+S` in IDE): Fast refresh for UI changes
- **Hot Restart** (`R` in terminal or `Ctrl+Shift+S` / `Cmd+Shift+S` in IDE): Full restart (needed for configuration changes)

## Environment Configuration

The project supports multiple configuration methods with a fallback chain:

1. **`.env` file** (highest priority for local development)
2. **`--dart-define` flags** (for CI/CD)
3. **Environment-aware defaults** (fallback)

### Configuration Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `ENVIRONMENT` | String | `development` | Environment: `development`, `staging`, or `production` |
| `BASE_URL` | String | Environment-aware | API base URL |
| `API_TIMEOUT` | int | `30` | API timeout in seconds |
| `ENABLE_LOGGING` | bool | Environment-aware | Enable logging |
| `ENABLE_ANALYTICS` | bool | Environment-aware | Enable analytics |
| `ENABLE_CRASH_REPORTING` | bool | Environment-aware | Enable crash reporting |

### Example `.env` File

```env
ENVIRONMENT=development
BASE_URL=http://localhost:3000
ENABLE_LOGGING=true
ENABLE_ANALYTICS=false
ENABLE_CRASH_REPORTING=false
```

### Using `--dart-define` Flags

```bash
flutter run \
  --dart-define=ENVIRONMENT=staging \
  --dart-define=BASE_URL=https://api-staging.example.com \
  --dart-define=ENABLE_ANALYTICS=true
```

### Accessing Configuration in Code

```dart
import 'package:flutter_starter/core/config/app_config.dart';

// Get environment
final env = AppConfig.environment;

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
```

For more details, see the [Configuration System](../../README.md#configuration-system) in the main README.

## Next Steps

- ✅ Continue to [Understanding the Codebase](understanding-codebase.md)
- ✅ Review [Common Tasks](../features/common-tasks.md) for development patterns
- ✅ Check [Troubleshooting](../support/troubleshooting.md) if you encounter issues

