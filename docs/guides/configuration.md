# Configuration System

This project includes a production-ready, multi-environment configuration system that supports:

- **Local Development**: `.env` files for easy local configuration
- **CI/CD**: `--dart-define` flags for build-time configuration
- **Fallback Chain**: `.env` → `--dart-define` → defaults
- **Environment-Aware Defaults**: Different configurations per environment
- **Feature Flags**: Enable/disable features per environment
- **Network Configuration**: Timeout settings for API calls
- **Debug Utilities**: Tools for inspecting configuration

## What works where

Both mechanisms have hard preconditions. Read this table before assuming a
value reaches the app.

| Mechanism | Precondition | Debug | Release / profile (AOT) | Flutter web |
|---|---|---|---|---|
| `.env` file | The file must be declared in the `assets:` list of `pubspec.yaml`. `flutter_dotenv` reads it through `rootBundle`, not the filesystem. | Yes | Yes | Yes |
| `--dart-define` | The key must be declared in `lib/core/config/dart_defines.dart`. | Yes | Yes | **No** |
| Defaults | None. | Yes | Yes | Yes |

Two consequences worth stating plainly:

- **`.env` is not loaded out of the box.** This repository ships only
  `.env.example` as an asset. Copying it to `.env` is not enough; you must also
  add `- .env` to `pubspec.yaml`. Until you do, `EnvConfig.load()` fails and
  `EnvConfig.isInitialized` stays `false`.
- **`--dart-define` is unavailable on Flutter web.** Every dart-define read in
  `EnvConfig` is guarded by `if (!kIsWeb)`, so on web the chain is `.env` →
  defaults only.

### Why the dart-define keys are declared in a table

`String.fromEnvironment` is a **const** constructor. The Dart SDK only
guarantees it works when invoked as `const`; an AOT-compiled binary (every
release and profile build) carries no compiler options at run time, so a
non-const invocation returns `''`. A call whose key is a runtime variable -
`String.fromEnvironment(key)` - can never be const, and that is exactly how
this repository used to read dart-defines: the value silently vanished in
release builds and everything fell back to the development defaults.

`lib/core/config/dart_defines.dart` therefore spells each key out as a literal
inside a `const` map, which the compiler resolves at build time. `EnvConfig`
indexes that map instead of querying the environment.

**Adding a new key** means adding it in two places: `.env.example` *and*
`DartDefines.values`. `test/core/config/dart_defines_test.dart` fails if the
two drift apart, so a key that only works through `.env` cannot slip in
unnoticed.

## Architecture

The configuration system consists of three classes:

1. **`DartDefines`** (`lib/core/config/dart_defines.dart`): the compile-time
   table of every supported `--dart-define` key
   - Each entry is a `const String.fromEnvironment('LITERAL_KEY')`
   - Keys not in the table can only be supplied through `.env`

2. **`EnvConfig`** (`lib/core/config/env_config.dart`): Low-level environment variable loader
   - Loads from `.env` files using `flutter_dotenv` (asset-backed)
   - Reads `--dart-define` values through `DartDefines`, on native builds only
   - Provides fallback chain: `.env` → `--dart-define` → defaults

3. **`AppConfig`** (`lib/core/config/app_config.dart`): High-level application configuration
   - Uses `EnvConfig` to extract robust application state properties.
   - Provides typed getters (String, bool, int)
   - Environment-aware defaults and Feature flags
   - Network timeout configuration

## Setup

### 1. Create `.env` file for local development

```bash
# Copy the example file
cp .env.example .env

# Edit .env with your values
# The .env file is gitignored and won't be committed
```

Then declare it as an asset, or it will never be read:

```yaml
# pubspec.yaml
flutter:
  assets:
    - .env.example
    - .env
```

### 2. Configure your environment variables

Edit `.env` with your configuration:

```env
ENVIRONMENT=development
BASE_URL=http://localhost:3000
ENABLE_LOGGING=true
ENABLE_ANALYTICS=false
```

---

## Usage Examples

### Local Development (using `.env` file)

1. Create `.env` file from `.env.example`
2. Fill in your values
3. Run the app normally:

```bash
flutter run
```

The app parses runtime overrides from `.env` **only if `.env` is listed under
`flutter: assets:` in `pubspec.yaml`** (see Setup step 1).

### Staging Build (using `--dart-define`)

For CI/CD or when you don't want to use `.env` files, you can inject values into the build directly. This works for native targets in every build mode; on Flutter web the flags are ignored by `EnvConfig`, and any key you pass must exist in `lib/core/config/dart_defines.dart`:

```bash
flutter run \
  --dart-define=ENVIRONMENT=staging \
  --dart-define=BASE_URL=https://api-staging.example.com \
  --dart-define=ENABLE_ANALYTICS=true
```

### Production Build (using `--dart-define`)

```bash
flutter build apk \
  --dart-define=ENVIRONMENT=production \
  --dart-define=BASE_URL=https://api.example.com \
  --dart-define=ENABLE_ANALYTICS=true \
  --dart-define=ENABLE_CRASH_REPORTING=true
```

---

## Using Configuration in Code

### Basic Checking

```dart
import 'package:flutter_starter/core/config/app_config.dart';

// Get environment
final env = AppConfig.environment; // 'development', 'staging', or 'production'

// Check environment
if (AppConfig.isDevelopment) {
  // Development-specific code
}

// Check feature flags
if (AppConfig.enableLogging) {
  logger.info('App started');
}

if (AppConfig.enableAnalytics) {
  analytics.trackEvent('app_opened');
}
```

### Network Configuration (Dio)

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

### Debug Utilities

```dart
import 'package:flutter_starter/core/config/app_config.dart';

// Print configuration to console (only in debug mode)
AppConfig.printConfig();

// Get configuration as a map
final config = AppConfig.getDebugInfo();
print(config);
```

---

## Available Configuration Options

### Environment Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `ENVIRONMENT` | String | `development` | Environment name: `development`, `staging`, or `production` |
| `BASE_URL` | String | Environment-aware | API base URL |
| `API_TIMEOUT` | int | `30` | API timeout in seconds |
| `API_CONNECT_TIMEOUT` | int | `10` | API connect timeout in seconds |
| `API_RECEIVE_TIMEOUT` | int | `30` | API receive timeout in seconds |
| `API_SEND_TIMEOUT` | int | `30` | API send timeout in seconds |
| `ENABLE_LOGGING` | bool | Environment-aware | Enable logging (default: true in dev/staging) |
| `ENABLE_ANALYTICS` | bool | Environment-aware | Enable analytics (default: true in staging/prod) |
| `ENABLE_CRASH_REPORTING` | bool | Environment-aware | Enable crash reporting (default: true in staging/prod) |
| `ENABLE_PERFORMANCE_MONITORING` | bool | Environment-aware | Enable performance monitoring |
| `ENABLE_DEBUG_FEATURES` | bool | Environment-aware | Enable debug features (default: true in dev) |
| `ENABLE_HTTP_LOGGING` | bool | Environment-aware | Enable HTTP loggers (default: true in dev) |
| `APP_VERSION` | String | `1.0.0` | App version |
| `APP_BUILD_NUMBER` | String | `1` | App build number |

### Fallback Defaults

**BASE_URL defaults:**
- Development: `http://localhost:3000`
- Staging: `https://api-staging.example.com`
- Production: `https://api.example.com`

**Feature Flag defaults:**
- Logging: Enabled in `development` and `staging`
- Analytics/Crash/Performance: Enabled in `staging` and `production`
- Debug Features: Enabled in `development` only
- HTTP Logging: Enabled in `development` only

---

## Best Practices & Troubleshooting

1. **Never commit `.env` files**: They contain sensitive information and are gitignored
2. **Use `.env.example` as a template**: Commit this file with placeholder values
3. **Use `.env` for local development**: Easy to change values without rebuilding
4. **Use `--dart-define` for CI/CD**: More secure and doesn't require file management
5. **Set environment-specific defaults**: Let the system handle defaults based on environment via `AppConfig`.

### Troubleshooting missing configuration
- Ensure `EnvConfig.load()` is called in `main()` before `runApp()`.
- **`.env` values ignored?** Check that `.env` is listed under `flutter: assets:` in `pubspec.yaml`. Without it `flutter_dotenv` cannot find the file and `EnvConfig.isInitialized` stays `false`.
- **`--dart-define` value ignored?** Check that the key exists in `lib/core/config/dart_defines.dart`, and that you are not on Flutter web (where dart-defines are skipped by the `kIsWeb` guard). `--dart-define` values are baked in at compile time: change one and you must rebuild, not hot reload.
- Hot reload doesn't reload system-level environment variables - do a full app restart.
- Run `flutter pub get` after pulling dependencies or updating flags to rebuild the configuration tree.
- Run `AppConfig.printConfig()` to inspect parsed fallback maps logic.
