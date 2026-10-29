# Getting Started

This guide will help you set up your development environment and get the Flutter Starter project running.

## Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK**: **3.47.0 or newer**
  - Check your version: `flutter --version`
  - Install/update: [Flutter Installation Guide](https://docs.flutter.dev/get-started/install)

- **Dart SDK**: **3.13.0 or newer** (included with Flutter)

> **Where those numbers come from.** The committed `pubspec.lock` records the
> resolved graph's requirements in its `sdks:` block
> (`dart: ">=3.13.0 <4.0.0"`, `flutter: ">=3.47.0"`), and `pubspec.yaml`'s
> `environment:` declares the same floors. On an older SDK, step 2 below
> (`flutter pub get`) stops with a message naming the SDK version it needs;
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
git clone <repository-url> my_app
cd my_app
```

Name the directory whatever you like; without the second argument `git clone`
names it after the repository (`flutter-starter` for this one).

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

### 4. Generated Code (nothing to run)

Generated code (Freezed, json_serializable, Riverpod) is committed, so a fresh
clone builds without running a generator. Regenerate only after you change an
annotated source - add or modify a `@freezed`, `@JsonSerializable` or
`@riverpod` declaration:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

While you are changing such sources, watch mode regenerates on every save:

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

# Run in profile mode (for performance testing). A release build also needs
# a signing key and ENVIRONMENT=staging or production: see
# docs/deployment/android-deployment.md#release-signing
flutter run --profile
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

### Connecting Your Backend

Setting `BASE_URL` points the app at your API, but the app also expects a
particular API. Check two things before the first sign-in:

- **Every request goes to `BASE_URL` + `/v1` + the endpoint path.** With
  `BASE_URL=https://api.example.com`, sign-in posts to
  `https://api.example.com/v1/auth/login`. The `/v1` is
  `ApiEndpoints.apiVersion` in `lib/core/constants/api_endpoints.dart`; it is
  read in two places, the client's base URL (`lib/core/network/api_client.dart`)
  and the token-refresh call (`lib/core/network/interceptors/auth_interceptor.dart`).
  Set it to `''` for an API that is not versioned, or to your own prefix.
- **The auth slice speaks a fixed wire format** - snake_case, on four
  endpoints:

  | Call | Endpoint | Request body | Response body |
  |---|---|---|---|
  | Login | `POST /auth/login` | `email`, `password` | `user`, `token`, `refresh_token` |
  | Register | `POST /auth/register` | `email`, `password`, `name` | `user`, `token`, `refresh_token` |
  | Refresh | `POST /auth/refresh` | `refresh_token` | `user`, `token`, `refresh_token` |
  | Logout | `POST /auth/logout` | none | ignored |

  `user` is an object with a string `id`, `email`, and optional `name` and
  `avatar_url`. The full contract, with an example body, is the
  [auth wire format](../../api/features/auth/models.md#wire-format). If your
  API differs, follow
  [Adapting the auth slice to an existing API](../../api/features/auth/models.md#adapting-the-auth-slice-to-an-existing-api),
  which lists the file to change for each difference. A mismatch does not always fail loudly: a camelCase
  `refreshToken` parses as no refresh token, and the session then ends at the
  first access-token expiry.

<!-- symbol: lib/core/constants/api_endpoints.dart ApiEndpoints.apiVersion -->

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

Each value resolves through this chain, per key:

1. **`--dart-define`** - which is how the documented `.env` setup arrives too:
   `--dart-define-from-file=.env` turns every line of the file into a
   dart-define. CI passes `--dart-define=KEY=value` flags directly.
2. **Environment-aware defaults** when neither supplies the key.

`EnvConfig` also checks a `.env` loaded at runtime with `EnvConfig.load()`
before the dart-defines, but nothing loads one by default: `.env` is not an
asset, and must not become one (see
[Never ship a secret in the bundle](../configuration.md#never-ship-a-secret-in-the-bundle)).

### Configuration Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `ENVIRONMENT` | String | `development` | Environment: `development`, `staging`, or `production` |
| `BASE_URL` | String | Environment-aware | API base URL. Requests go to `BASE_URL` + `/v1` + the path (`https://api.example.com/v1/auth/login`); see [Connecting Your Backend](#connecting-your-backend) to change the `/v1` |
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


