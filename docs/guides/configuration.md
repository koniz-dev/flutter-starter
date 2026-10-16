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

An asset-backed `.env` is never needed to configure a build: `--dart-define`
and `--dart-define-from-file` work on every target, Flutter web included. A
bundled `.env` is still allowed, for values you would be happy to publish,
because publishing them is exactly what it does. The usual reason is runtime
configuration that must change without a rebuild.

Until koniz-dev/flutter-starter#278 this section called web the exception.
`EnvConfig` used to skip every dart-define read behind `if (!kIsWeb)`, which
left a bundled `.env` as the only way to configure a web build. That guard was
never a platform limitation: dart2js resolves the const `DartDefines` table the
same way the native compilers do, and the guard is gone.

`tool/check_env_assets.dart` fails when a secrets file would be bundled. It
runs in four places:

- `./scripts/dev/audit_template.sh`, as its own step;
- `test/tooling/check_env_assets_test.dart`, so `flutter test` - and therefore
  the CI **Quality gate** - fails on a commit that adds one;
- `scripts/ci/build_all.sh`, after `flutter pub get` and before the first
  build, so a local tree that never reached CI cannot produce an artifact; and
- `deploy-android.yml`, `deploy-ios.yml` and all three jobs of
  `deploy-web.yml`, as a **Guard against a bundled secrets file** step placed
  after every step that writes into the working tree and before the build
  (koniz-dev/flutter-starter#135).

It checks the two ways a file gets bundled:

1. **Named in the list** - `- .env` and friends, in every spelling Flutter
   accepts: a block list entry, the map form `- path: .env` that `flavors:`
   and `transformers:` need, a flow list `assets: [.env.example, .env]`, and
   the asset lists under `deferred-components:`.
2. **Inside a declared directory** - this repository declares `assets/images/`
   and `assets/config/`, and a directory entry bundles every file directly
   inside it. A `.env` dropped into `assets/config/` ships with an *empty*
   pubspec diff, so nothing in review would catch it; `.env` is gitignored, so
   no secret scanner sees it either. The guard walks those directories,
   whether they are declared as `- assets/config/` or `- path: assets/config/`.

The list is read with a real YAML parse, and only the acknowledgement comment
is read from the raw text. Until koniz-dev/flutter-starter#330 a hand-written
line scan read block-style `- <path>` lines only, so the map and flow forms
exited 0 while `flutter build bundle` copied the `.env` into the artifact. Now
anything the parse cannot read for certain - invalid YAML, an `assets:` that is
not a list, a map entry with no `path:`, an entry that is not a path string -
**exits 2**. The guard fails closed: it never reports a list clean that it did
not read.

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

### What a given comment covers

The names are matched **exactly**, so you can compute the covered set by eye:

```
ack       := 'env-asset-ack:' names? separator? prose?
names     := name (',' name)*
name      := a bare file name containing a dot - no spaces, no directory part
separator := ';' | an em or en dash | a hyphen with spaces around it
             | the first ',' segment that is not a name
```

The covered set is the **leading comma-separated run of bare file names**, and
each one must equal the file's own name (case-insensitively). Everything from
the first segment that is not a file name onwards is prose and covers nothing.

| Comment on `- assets/config/` | Covers | Does not cover |
|---|---|---|
| `# env-asset-ack: .env.web` | `.env.web` | anything else |
| `# env-asset-ack: .env.web, publishable values only` | `.env.web` | `.env` |
| `# env-asset-ack: .env.web - publishable values only` | `.env.web` | `.env` |
| `# env-asset-ack: .env.web, .env.staging - publishable` | both named files | `.env` |
| `# env-asset-ack: .env.example, publishable placeholders only` | `.env.example` | **`.env`** |
| `# env-asset-ack: .env.web only; there is no .env here` | nothing - the first segment is prose | everything, including `.env.web` |

The last two rows are the point. Until
koniz-dev/flutter-starter#170 the match was a substring test against the whole
comment, and every env file name is a prefix of a longer one: an ack naming
`.env.example` also acknowledged a real `.env`, and even a sentence *denying*
that a `.env` existed acknowledged it, because the denial contains the name. A
malformed acknowledgement now covers nothing rather than everything - it fails
closed, and the guard tells you which file is still unacknowledged.

A name that matches no file in the directory is **stale**. The guard prints a
`note:` on stderr and does not fail: `.env` is gitignored and a web deployment
may write its env file at deploy time, so a fresh checkout can legitimately
lack the acknowledged file, and failing there would red-light a clean CI run on
a tree that is strictly safer. A stale name cannot hide anything either - the
file it names is not present, and any file that is present is matched exactly
or reported. Delete the name when the file is gone for good.

An acknowledgement on a **file** entry does not have to name anything: the entry
already names exactly one file, so the comment cannot widen what it covers. For
a map-form entry, put it on the `path:` line:

```yaml
    - path: .env # env-asset-ack: web build, contains no secrets
      flavors: [web]
```

A comment on another line of the same entry (the `flavors:` line, say) covers
nothing. In a **flow list** several entries share one line and one comment, so
there the comment must name each file it covers, exactly as on a directory:
`assets: [.env.example, .env] # env-asset-ack: .env - web build`.

The guard then passes and prints a reminder on stderr instead of failing. An
environment variable would not have that property, which is why the escape hatch
is a comment in the repository rather than a flag on the command line.

One thing it cannot do: it sees the tree **at the moment it runs**, so a file
created after the check still ships. That is why the release-build copies of it
sit as late as they can - after `flutter pub get` in `scripts/ci/build_all.sh`,
and after the keystore and certificate steps in the deploy workflows - rather
than at the top of the job.

`scripts/ci/release.sh` has no build step of its own and refuses to run with a
dirty working tree, so it reaches a build only through one of the paths above.

Before any release, and as the release-checklist line for this:
`dart run tool/check_env_assets.dart` exits 0, and any acknowledged entry it
reports has been re-read for secrets.

## What works where

Both mechanisms have hard preconditions. Read this table before assuming a
value reaches the app.

| Mechanism | Precondition | Debug | Release / profile (AOT) | Flutter web |
|---|---|---|---|---|
| `.env` file | The file must be declared in the `assets:` list of `pubspec.yaml` - which ships it to every user. `flutter_dotenv` reads it through `rootBundle`, not the filesystem. | Yes | Yes | Yes |
| `--dart-define` / `--dart-define-from-file` | The key must be declared in `lib/core/config/dart_defines.dart`. | Yes | Yes | Yes |
| Defaults | None. | Yes | Yes | Yes |

Two consequences worth stating plainly:

- **`.env` is not loaded out of the box, and should usually stay that way.**
  This repository ships only `.env.example` as an asset. Copying it to `.env` is
  not enough - `flutter_dotenv` can only read an asset - so until `.env` is
  declared in `pubspec.yaml`, `EnvConfig.load()` fails and
  `EnvConfig.isInitialized` stays `false`. Declaring it publishes it, so on
  native use `--dart-define-from-file=.env` instead and leave the asset list
  alone.
- **`--dart-define` works on Flutter web too**, with the same key table.
  Everything compiled into a web build is still public: `main.dart.js` is
  downloaded by every visitor, and a define is a string literal inside it.
  That is no different from native, where it is a string in the binary. The
  rule from [Never ship a secret in the bundle](#never-ship-a-secret-in-the-bundle)
  applies unchanged.

### Feature flags

**No build mechanism sets a `FEATURE_*` variable.** Neither `.env` nor
`--dart-define` nor `--dart-define-from-file` reaches a local feature flag, on
any target and in any build mode. `LocalFeatureFlagsService` used to promise
an "environment" level, `FEATURE_<KEY>`, as its top priority. It looked the key
up through `EnvConfig`, and a key built at run time from the flag name is never
in the `DartDefines` table, so the define was discarded everywhere. The level
was removed in koniz-dev/flutter-starter#279 rather than left as a source that
cannot fire.

What does decide a local flag, highest first:

1. A local override, written by the feature-flags debug screen.
2. The remote source, if you replace the shipped no-op one.
3. The definition's `debugDefault` or `releaseDefault` for the current build
   mode.
4. The definition's `compileTimeDefault`.
5. The flag's `FeatureFlagKey.defaultValue` in `FeatureFlags`, when nothing
   above sets it.

`FeatureFlagsManager.isEnabled`, `isFeatureEnabledProvider` and the debug
screen all resolve a flag through this one order, so they cannot disagree
about it (koniz-dev/flutter-starter#318). The debug screen lists every
`FeatureFlags.all` key, including keys at level 5. A toggle there refreshes
every provider that reads a flag, not only the screen's own list.

To flip a flag per build anyway, make its default a literal compile-time read.
That is the same const mechanism the table uses, so it works on every target in
the table above:

```dart
const LocalFlagDefinition(
  key: 'enable_experimental_features',
  compileTimeDefault: bool.fromEnvironment('FEATURE_ENABLE_EXPERIMENTAL_FEATURES'),
),
```

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
same file up without bundling it, on every target, web included, and in every
build mode. Adding `- .env` to `pubspec.yaml` would ship your values to every user;
see [Never ship a secret in the bundle](#never-ship-a-secret-in-the-bundle).

On Flutter web the same flags work, but a web build is public by
construction. Pass publishable values only, and fetch anything private from
your backend at run time.

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

For CI/CD or when you don't want to use `.env` files, you can inject values into the build directly. This works on every target, Flutter web included, in every build mode. Any key you pass must exist in `lib/core/config/dart_defines.dart`:

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
| `ENABLE_ANALYTICS` | bool | Environment-aware | **Reserved, not wired.** Parsed into `AppConfig.enableAnalytics`, but the starter ships no analytics, so nothing reads it. Gate your analytics SDK on it (default: true in staging/prod) |
| `ENABLE_CRASH_REPORTING` | bool | Environment-aware | **Reserved, not wired.** Parsed into `AppConfig.enableCrashReporting`, but the starter ships no crash reporter, so nothing reads it. Gate your crash reporter on it (default: true in staging/prod) |
| `ENABLE_PERFORMANCE_MONITORING` | bool | Environment-aware | Enable performance monitoring |
| `ENABLE_DEBUG_FEATURES` | bool | Environment-aware | Registers the `/feature-flags-debug` route; without it the route does not exist (default: true in dev only) |
| `ENABLE_HTTP_LOGGING` | bool | Environment-aware | Enable HTTP loggers (default: true in dev) |
| `APP_VERSION` | String | `1.0.0` | App version |
| `APP_BUILD_NUMBER` | String | `1` | App build number |

`test/core/config/enable_toggles_have_readers_test.dart` keeps the
`ENABLE_*` rows honest. A row marked **Reserved** must have no reader
outside `lib/core/config/`, and every other row must have one. Wiring a
reserved toggle, or adding a toggle nothing reads, fails that test until
the row is updated.

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
- **`--dart-define` value ignored?** Check that the key exists in `lib/core/config/dart_defines.dart`. A key missing from that table is ignored on every platform, web included. `--dart-define` values are baked in at compile time: change one and you must rebuild, not hot reload.
- Hot reload doesn't reload system-level environment variables - do a full app restart.
- Run `flutter pub get` after pulling dependencies or updating flags to rebuild the configuration tree.
- Run `AppConfig.printConfig()` to inspect parsed fallback maps logic.
