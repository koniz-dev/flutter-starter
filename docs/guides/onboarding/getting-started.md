# Getting Started

This guide will help you set up your development environment and get the Flutter Starter project running.

## Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK**: **3.47.0 or newer**
  - Check your version: `flutter --version`
  - Install/update: [Flutter Installation Guide](https://docs.flutter.dev/get-started/install)

- **Dart SDK**: **3.13.0 or newer** (included with Flutter)

> **Where those numbers come from.** The committed `pubspec.lock` records the
> resolved graph's requirements in its `sdks:` block:
> `dart: ">=3.13.0 <4.0.0"`, `flutter: ">=3.47.0"`. `pubspec.yaml` declares
> only `environment: sdk: '^3.8.0'` and carries **no `flutter:` constraint**,
> so an older SDK does not produce a clear "upgrade Flutter" message - step 2
> below (`flutter pub get`) fails with a version-solve error naming a
> transitive package such as `path_provider_foundation`. If you see that,
> upgrade Flutter before anything else.

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

# Feed it to the build - this is how it is read, on every native target
flutter run --dart-define-from-file=.env
```

Do **not** add `- .env` to the `assets:` list in `pubspec.yaml` to make plain
`flutter run` pick it up. Flutter asset lists are not build-mode scoped, so
that ships your values inside every release APK, IPA and web build. See
[Never ship a secret in the bundle](../configuration.md#never-ship-a-secret-in-the-bundle).

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
# Run on connected device/emulator, reading the .env from step 3
flutter run --dart-define-from-file=.env

# Without a .env: built-in development defaults
flutter run

# Run on specific device
flutter devices  # List available devices
flutter run -d <device-id>

# Run in release mode (for performance testing)
flutter run --release
```

### Signing In Before You Have a Backend

A debug build with `ENVIRONMENT=development` and no `BASE_URL` signs in
against an in-process demo account instead of the network, so the app runs
end to end on day one. The login screen shows a "Demo mode" card; its button
fills `demo@example.com` / `demo1234`. Registering also works and lasts until
the app restarts.

One rule decides whether there is a backend: `AppConfig.hasBackend`, true
once `BASE_URL` is set (in `.env` or with `--dart-define`) or the environment
is anything but `development`. Demo mode is on exactly when it is false in a debug
build, so it turns itself off with a `BASE_URL` - a local server included,
which therefore needs `BASE_URL=http://localhost:3000` spelled out - and in
every profile or release build.
<!-- symbol: lib/core/config/app_config.dart AppConfig.hasBackend --> A demo session stays signed in after that switch until you sign out, so
sign out (or clear the app's data) before pointing the app at a real backend.
<!-- symbol: lib/features/auth/demo/demo_auth.dart DemoAuth -->
To remove it entirely:

1. Delete `lib/features/auth/demo/`, `test/features/auth/demo/` and
   `test/flutter_test_config.dart`.
2. Delete the lines `git grep -n -e DemoAuth -e DemoSignInCard -e auth/demo lib`
   still lists: two imports and one line in `auth_providers.dart`, two
   imports and the `if (DemoAuth.enabled)` block in `login_screen.dart`.
3. Delete this section.

`flutter analyze` and `flutter test` then pass; the `demoMode*` strings in
`lib/l10n/` are unused and can go too.

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
| `API_TIMEOUT` | int | `30` | End-to-end deadline per request, in seconds, retries included (see [configuration](../configuration.md#environment-variables)) |
| `ENABLE_LOGGING` | bool | Environment-aware | Enable logging |
| `ENABLE_ANALYTICS` | bool | Environment-aware | Enable analytics |
| `ENABLE_CRASH_REPORTING` | bool | Environment-aware | Enable crash reporting |

<!-- symbol: lib/core/network/adapters/dio_network_client.dart DioNetworkClient -->

### Example `.env` File

```env
ENVIRONMENT=development
BASE_URL=http://localhost:3000
ENABLE_LOGGING=true
ENABLE_ANALYTICS=false
ENABLE_CRASH_REPORTING=false
```

> **Android emulator:** `localhost` there is the emulator itself, not your machine. A backend running on your machine is reached at `http://10.0.2.2:<port>` (for example `BASE_URL=http://10.0.2.2:3000`). The iOS Simulator, desktop and web builds use `localhost` as shown.

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

For more details, see the [Configuration guide](../configuration.md).

## Next Steps

- Continue to [Understanding the Codebase](understanding-codebase.md)
- Review [Common Tasks](../features/common-tasks.md) for development patterns
- Check [Troubleshooting](../support/troubleshooting.md) if you encounter issues


