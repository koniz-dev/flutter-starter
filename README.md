# flutter_starter

A production-ready Flutter starter project with clean architecture and enterprise-grade configuration management.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Configuration System

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
