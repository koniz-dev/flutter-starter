# Configuration System

This project includes a production-ready, multi-environment configuration system that supports:

- **Local Development**: `.env` files for easy local configuration
- **CI/CD**: `--dart-define` flags for build-time configuration
- **Fallback Chain**: `.env` → `--dart-define` → defaults
- **Environment-Aware Defaults**: Different configurations per environment
- **Feature Flags**: Enable/disable features per environment
- **Network Configuration**: Timeout settings for API calls
- **Debug Utilities**: Tools for inspecting configuration

## Never ship a secret in the bundle

Read this before the mechanics. It is the one thing in this guide that costs
money to get wrong.

**A Flutter `assets:` declaration is not build-mode scoped.** There is no
debug-only asset list. Anything listed under `flutter: assets:` is copied into
the release APK, the release IPA and the web build exactly as it is copied into
a debug build. So a `.env` declared as an asset is:

- **extractable from a release APK or IPA** by anyone who unzips it - no root,
  no jailbreak, no instrumentation, and this is scanned for automatically at
  scale;
- **fetchable over HTTP on web**, unauthenticated, at
  `https://<your-host>/assets/.env`, and listed in `AssetManifest.json`.

Once such a build is published the only remedy is rotating every value in the
file, and nothing warns you: `.env` is gitignored, so no secret scanner ever
sees it.

An earlier version of this guide told you to add `- .env` to `pubspec.yaml`.
**Do not.** What to do instead:

| Target | Supported way to configure a release build | Can it hold a secret? |
|---|---|---|
| Android, iOS, macOS, Windows, Linux | `--dart-define-from-file=.env` (or individual `--dart-define` flags). Nothing is bundled as a readable file. | Not really - see below |
| Flutter web | Nothing in the bundle. Values that must stay private come from your backend at run time. | **No. Never.** |

`flutter run`, `flutter build apk`, `flutter build ipa` and friends all accept
`--dart-define-from-file=<file.json|file.env>`, so your existing `.env` works
unchanged as a *build input* without ever becoming an asset:

```bash
flutter run --dart-define-from-file=.env
flutter build apk --release --dart-define-from-file=.env
```

Two honest caveats.

- **A dart-define is not a vault.** The values are compiled into the binary and
  are recoverable from it with ordinary reverse-engineering tools. Moving a key
  from an asset to a dart-define raises the cost of reading it from "unzip" to
  "disassemble"; it does not make it private. Treat dart-defines as build
  configuration - environment name, base URL, feature flags - not as secret
  storage.
- **A web client cannot hold a secret at all.** The browser downloads your
  entire bundle; there is nowhere in it to hide anything. Any credential that
  matters must live on a server the client authenticates to, which then either
  proxies the call or hands back a short-lived, scoped token. This is a
  property of shipping code to a user agent, not a limitation of this template.

So: API keys, client secrets, signing material, database URLs and admin tokens
never belong in `.env`, in a dart-define, or in any other part of a client
build, on any platform.

### The deliberate exception, and the guard

Web is the awkward case: `EnvConfig` guards every dart-define read with
`if (!kIsWeb)`, so on web an asset-backed `.env` is the *only* runtime
configuration mechanism there is. That is allowed - for values you would be
happy to publish, because publishing them is exactly what it does.

`tool/check_env_assets.dart` fails when a secrets file would be bundled. It
runs in two places:

- `./scripts/dev/audit_template.sh`, as its own step; and
- `test/tooling/check_env_assets_test.dart`, so `flutter test` - and therefore
  the CI **Quality gate** - fails on a commit that adds one.

It checks the two ways a file gets bundled:

1. **Named in the list** - `- .env` and friends.
2. **Inside a declared directory** - this repository declares `assets/images/`
   and `assets/config/`, and a directory entry bundles every file directly
   inside it. A `.env` dropped into `assets/config/` ships with an *empty*
   pubspec diff, so nothing in review would catch it; `.env` is gitignored, so
   no secret scanner sees it either. The guard walks those directories.

What counts as a secrets file, by name only - nothing reads file contents:

| Matched | Not matched |
|---|---|
| `.env` and `.env.*` (except `.env.example`) | `.env.example` |
| `.pem`, `.key`, `.p12`, `.pfx`, `.p8`, `.jks`, `.keystore`, `.mobileprovision`, `.provisionprofile` | `.cer`, `.crt`, `.der` - a certificate is public by design, and a pinning setup may legitimately ship one |
| `secrets.{json,yaml,yml}`, `credentials.json`, `service-account.json`, `key.properties`, `google-services.json`, `GoogleService-Info.plist` | `config.json`, `app_config.yaml` and other ordinary configuration |

The boundary is deliberate. A rule that fired on `config.json` inside a
directory named `assets/config/` would be wrong on its first run, and a guard
that cries wolf gets switched off rather than fixed. The cost is the other
direction: a secret inside an innocuously named file is not detected.

To take the web exception, acknowledge it inline. The marker is committed next
to the entry, so it appears in the diff and in review:

```yaml
# pubspec.yaml
flutter:
  assets:
    - .env.example
    - .env # env-asset-ack: web build, contains no secrets
```

For a file inside a declared directory there is no line of its own, so the
acknowledgement goes on the **directory** entry and has to **name the file**:

```yaml
    - assets/config/ # env-asset-ack: .env.web, publishable values only
```

Naming it is what keeps the exception narrow: the same comment does not silence
the next file somebody drops into that directory.

The guard then passes and prints a reminder instead of failing. An environment
variable would not have that property, which is why the escape hatch is a
comment in the repository rather than a flag on the command line.

Two things it cannot do. It sees the tree **at the moment it runs**, so a file
created after the check still ships; and it is not on the release-build path -
`scripts/ci/build_all.sh` and the deploy workflows can build a tree the guard
never ran against (koniz-dev/flutter-starter#135). Run it before a release, as
below.

Before any release, and as the release-checklist line for this:
`dart run tool/check_env_assets.dart` exits 0, and any acknowledged entry it
reports has been re-read for secrets.

## What works where

Both mechanisms have hard preconditions. Read this table before assuming a
value reaches the app.

| Mechanism | Precondition | Debug | Release / profile (AOT) | Flutter web |
|---|---|---|---|---|
| `.env` file | The file must be declared in the `assets:` list of `pubspec.yaml` - which ships it to every user. `flutter_dotenv` reads it through `rootBundle`, not the filesystem. | Yes | Yes | Yes |
| `--dart-define` / `--dart-define-from-file` | The key must be declared in `lib/core/config/dart_defines.dart`. | Yes | Yes | **No** |
| Defaults | None. | Yes | Yes | Yes |

Two consequences worth stating plainly:

- **`.env` is not loaded out of the box, and should usually stay that way.**
  This repository ships only `.env.example` as an asset. Copying it to `.env` is
  not enough - `flutter_dotenv` can only read an asset - so until `.env` is
  declared in `pubspec.yaml`, `EnvConfig.load()` fails and
  `EnvConfig.isInitialized` stays `false`. Declaring it publishes it, so on
  native use `--dart-define-from-file=.env` instead and leave the asset list
  alone.
- **`--dart-define` is unavailable on Flutter web.** Every dart-define read in
  `EnvConfig` is guarded by `if (!kIsWeb)`, so on web the chain is `.env` →
  defaults only, and everything in it is public.

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

Then feed it to the build as a **dart-define file**, not as an asset:

```bash
flutter run --dart-define-from-file=.env
```

`flutter_dotenv` can only read an asset, so an undeclared `.env` is never
loaded through `EnvConfig`'s dotenv layer - but the dart-define layer picks the
same file up without bundling it, on every native target and in every build
mode. Adding `- .env` to `pubspec.yaml` would ship your values to every user;
see [Never ship a secret in the bundle](#never-ship-a-secret-in-the-bundle).

On Flutter web there is no dart-define path. Configure web builds with
publishable values only, and fetch anything private from your backend at run
time.

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
3. Run the app with the file as a dart-define source:

```bash
flutter run --dart-define-from-file=.env
```

Plain `flutter run` will **not** pick the file up: `EnvConfig`'s dotenv layer
reads assets, and `.env` is deliberately not an asset (see
[Never ship a secret in the bundle](#never-ship-a-secret-in-the-bundle)). Keys
passed this way must exist in `lib/core/config/dart_defines.dart`.

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
2. **Never bundle `.env` as an asset**: assets are not build-mode scoped, so it ships to every user. See [Never ship a secret in the bundle](#never-ship-a-secret-in-the-bundle)
3. **Use `.env.example` as a template**: Commit this file with placeholder values
4. **Use `--dart-define-from-file=.env` for local development**: same file, same convenience, nothing bundled
5. **Use `--dart-define` for CI/CD**: keeps values out of the asset list; supply them from the CI secret store, never from a committed file
6. **Keep real secrets out of every client build**: on web that is not a preference but a fact - serve them from your backend instead
7. **Set environment-specific defaults**: Let the system handle defaults based on environment via `AppConfig`.

### Troubleshooting missing configuration
- Ensure `EnvConfig.load()` is called in `main()` before `runApp()`.
- **`.env` values ignored?** Expected: `.env` is not an asset, on purpose. Pass `--dart-define-from-file=.env` instead, and check the keys exist in `lib/core/config/dart_defines.dart`. Declaring `.env` under `flutter: assets:` would make `flutter_dotenv` find it - and publish it in every build; `dart run tool/check_env_assets.dart` fails if you do.
- **`--dart-define` value ignored?** Check that the key exists in `lib/core/config/dart_defines.dart`, and that you are not on Flutter web (where dart-defines are skipped by the `kIsWeb` guard). `--dart-define` values are baked in at compile time: change one and you must rebuild, not hot reload.
- Hot reload doesn't reload system-level environment variables - do a full app restart.
- Run `flutter pub get` after pulling dependencies or updating flags to rebuild the configuration tree.
- Run `AppConfig.printConfig()` to inspect parsed fallback maps logic.
