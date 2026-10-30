# Security Implementation Guide

This guide provides step-by-step instructions and code examples for implementing the security recommendations from the [Security Audit Report](./audit.md).

---

## RASP / FreeRASP (optional)

By default the app uses a **no-op** implementation via [`raspServiceProvider`](../../../lib/core/security/rasp_providers.dart) (`NoOpRaspService`), so nothing is enforced until you override the provider with a concrete implementation. A `freerasp` adapter, `FreeRaspServiceImpl`, ships as an opt-in template (`lib/core/security/infrastructure/freerasp_service_impl.dart.template`); `freerasp` itself is **not** a default dependency, because it links a closed-source SDK and adds Android permissions even while RASP is unused (section 7). Enabling real RASP requires FreeRASP configuration, platform setup, and usually a commercial agreement—see the [FreeRASP documentation](https://docs.talsec.app/freerasp).

---

## Table of Contents

1. [Critical Fixes](#critical-fixes)
   - [SSL Certificate Pinning](#1-ssl-certificate-pinning) (shipped - configure only)
   - [Code Obfuscation](#2-code-obfuscation)
   - [Log Sanitization](#3-log-sanitization)
   - [Android Release Signing](#4-android-release-signing)
   - [Security Headers](#5-security-headers)

2. [High Priority Fixes](#high-priority-fixes)
   - [Network Security Config](#6-network-security-config)
   - [Root/Jailbreak Detection](#7-rootjailbreak-detection-freerasp)
   - [Session Management](#8-session-management-blueprint)

3. [Compliance Features](#compliance-features)
   - [GDPR Consent Management](#9-gdpr-consent-blueprint)

---

## Conventions (shipped code vs blueprints)

- **In this repository:** Prefer paths that exist under `lib/` today (see [Contracts map](../../architecture/contracts-map.md)).
- **Blueprints:** Optional modules (session timeout, GDPR UI, extra SSL snippets) live in **[blueprints.md](./blueprints.md)** — not in `lib/`. Use as templates only.

## Critical Fixes

### 1. SSL Certificate Pinning

**Already implemented.** Do not add a pinning package and do not rewrite
`ApiClient`. This section tells you how to *configure* what ships.

#### What ships

`ApiClient._createDio` installs an `IOHttpClientAdapter` whose
`badCertificateCallback` SHA-256s the presented certificate's DER bytes and
accepts the connection only if that digest is in the configured pin set
(`SslPinning.createAdapter()` in `lib/core/network/ssl_pinning.dart`). The `HttpClient` is constructed
with an empty `SecurityContext()`, so the platform trust store is bypassed and
every certificate goes through the callback.

**Not on web.** A browser owns TLS. There is no `SecurityContext` and no
`HttpClient`, and the page never sees the server certificate, so an app cannot
pin on Flutter web. There, `SslPinning.createAdapter()` returns `null` and
`isEffective` is `false` whatever `ENABLE_SSL_PINNING` and
`API_SSL_FINGERPRINTS` say, so the web build uses the browser's own transport
and trust store. It used to install the dart:io adapter anyway, and every web request failed with
`Unsupported operation: SecurityContext constructor`. If a web client needs
stronger guarantees, enforce them on the server side, for example with HSTS
and Certificate Transparency monitoring. There is no app-side substitute.

The pin set and the on/off switch come from `AppConfig`
(`apiSslFingerprints` and `enableSslPinning` in `lib/core/config/app_config.dart`):

<!-- symbol: lib/core/network/ssl_pinning.dart SslPinning.createAdapter -->
<!-- symbol: lib/core/config/app_config.dart AppConfig.apiSslFingerprints -->
<!-- symbol: lib/core/config/app_config.dart AppConfig.enableSslPinning -->

| Setting | Env variable | Default |
|---|---|---|
| `AppConfig.apiSslFingerprints` | `API_SSL_FINGERPRINTS` | empty list |
| `AppConfig.enableSslPinning` | `ENABLE_SSL_PINNING` (`true`/`1`/`yes`/`on` or `false`/`0`/`no`/`off`, any case; any other value keeps the default and a release refuses to start) | `true` in staging and production; in development `true` once `API_SSL_FINGERPRINTS` is set, `false` otherwise |

Fingerprints are normalised on read: comma-separated, colons stripped,
lowercased. Supply them in either form.

#### Step 1: Extract your certificate fingerprint

```bash
# For your API server
openssl s_client -servername api.example.com -connect api.example.com:443 < /dev/null | \
  openssl x509 -fingerprint -sha256 -noout -in /dev/stdin

# Output example:
# SHA256 Fingerprint=AA:BB:CC:DD:EE:FF:...
```

Pin at least two values - the certificate you serve today and the one you will
rotate to - or a rotation will brick every installed client.

#### Step 2: Set the environment variables

```bash
# .env (and your CI secret store)
API_SSL_FINGERPRINTS=aabbccddeeff...,bbccddeeffaa...
ENABLE_SSL_PINNING=true
```

`.env.example` already carries both keys, empty.

#### Step 3: Verify it is actually on

Pinning is decided by `SslPinning.createAdapter()` in
`lib/core/network/ssl_pinning.dart`, which `ApiClient` calls when it builds its
transport. It installs the pinned adapter only when `ENABLE_SSL_PINNING` is on
**and** `API_SSL_FINGERPRINTS` is non-empty.

<!-- symbol: lib/core/network/ssl_pinning.dart SslPinning -->

<!-- symbol: lib/core/config/app_config.dart AppConfig.releasePinningMisconfigured -->

Requesting pinning with no fingerprints does not fail quietly:
`createAdapter()` logs `SSL PINNING MISCONFIGURED: ...` and trips an assertion
in debug builds. A release build refuses to start on it: `main()` checks
`AppConfig.releasePinningMisconfigured` and shows the startup failure screen,
naming `API_SSL_FINGERPRINTS`. Set `ENABLE_SSL_PINNING=false` to ship a
release without pinning on purpose. `AppConfig.printConfig()` prints `SSL Pinning Requested`,
`SSL Pinning Effective` and `SSL Fingerprints Configured`, and adds a
`!! SSL PINNING MISCONFIGURED` line in that case. `Effective: true` is the only
reading that means traffic is pinned. Pinning never applies on Flutter web,
where the browser owns TLS.

Then point a proxy (Charles, Proxyman, Burp) at the app: with pinning active
the request must fail, not succeed.

**Note:** treat fingerprints as configuration, not secrets, but keep production
values out of the repository so a rotation does not require a code change.

---

### 2. Code Obfuscation

#### Step 1: Update Build Scripts

Create a build script:

```bash
#!/bin/bash
# scripts/ci/build_release.sh
set -euo pipefail

ENVIRONMENT=${1:-production}
BUILD_TYPE=${2:-apk}  # apk, appbundle, ios

# Each environment gets its own API host. Export BASE_URL to override it.
case "$ENVIRONMENT" in
  production) BASE_URL=${BASE_URL:-https://api.example.com} ;;
  staging)    BASE_URL=${BASE_URL:-https://api-staging.example.com} ;;
  *)
    echo "Unknown environment '$ENVIRONMENT' (expected production or staging)" >&2
    exit 1
    ;;
esac

# Pinning is on by default in staging and production. With an empty list,
# the release refuses to start, so refuse to build it in the first place.
if [ -z "${API_SSL_FINGERPRINTS:-}" ]; then
  echo "API_SSL_FINGERPRINTS is empty: refusing to build an unpinned release" >&2
  exit 1
fi

case "$BUILD_TYPE" in
  apk|appbundle|ios) ;;
  *)
    echo "Unknown build type '$BUILD_TYPE' (expected apk, appbundle or ios)" >&2
    exit 1
    ;;
esac

echo "Building $BUILD_TYPE for $ENVIRONMENT with obfuscation..."

flutter build "$BUILD_TYPE" --release \
  --obfuscate \
  --split-debug-info=./build/debug-info \
  --dart-define=ENVIRONMENT="$ENVIRONMENT" \
  --dart-define=BASE_URL="$BASE_URL" \
  --dart-define=API_SSL_FINGERPRINTS="$API_SSL_FINGERPRINTS"

echo "Build complete. Debug info saved to ./build/debug-info/"
echo " IMPORTANT: Store debug-info files securely for crash symbolication!"
```

Only keys listed in `DartDefines.values` (`lib/core/config/dart_defines.dart`)
reach the app through `--dart-define`; any other key is dropped at compile
time without an error. The fingerprint key is `API_SSL_FINGERPRINTS`, a
comma-separated list of SHA-256 fingerprints, as in section 1.

Make it executable:
```bash
chmod +x scripts/ci/build_release.sh
```

#### Step 2: Update CI/CD

```yaml
# .github/workflows/build.yml (example)
name: Build Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build-android:
    runs-on: ubuntu-latest
    steps:
      # Pinned to a commit, not a tag: a tag can be moved, and this job holds
      # your release secrets. Dependabot keeps the SHA and comment current.
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2 # v2.23.0
        with:
          # Floating stable, as this repository's own workflows do: a pinned
          # version can fall below pubspec.yaml's `sdk:` constraint.
          channel: 'stable'
      
      # The release build is refused without android/key.properties. Store
      # the keystore and its passwords as secrets (the same step ships,
      # commented out, in .github/workflows/deploy-android.yml).
      - name: Setup Android keystore
        env:
          KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
          KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
          KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
        run: |
          echo "$KEYSTORE_BASE64" | base64 -d > android/upload-keystore.jks
          echo "storePassword=$KEYSTORE_PASSWORD" > android/key.properties
          echo "keyPassword=$KEY_PASSWORD" >> android/key.properties
          echo "keyAlias=$KEY_ALIAS" >> android/key.properties
          echo "storeFile=upload-keystore.jks" >> android/key.properties

      - name: Build APK
        run: |
          flutter build apk --release \
            --obfuscate \
            --split-debug-info=./build/debug-info \
            --dart-define=ENVIRONMENT=production \
            --dart-define=BASE_URL=${{ secrets.BASE_URL }} \
            --dart-define=API_SSL_FINGERPRINTS="${{ secrets.API_SSL_FINGERPRINTS }}"
      
      - name: Upload Debug Info
        uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
        with:
          name: debug-info
          path: build/debug-info/
          retention-days: 365
      
      - name: Upload APK
        uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
        with:
          name: app-release
          path: build/app/outputs/flutter-apk/app-release.apk
```

#### Step 3: Update Documentation

Add to your platform deployment guides,
[`docs/deployment/android-deployment.md`](../../deployment/android-deployment.md)
and [`docs/deployment/ios-deployment.md`](../../deployment/ios-deployment.md):

```markdown
## Production Builds

### With Obfuscation

Always use obfuscation for production builds. A release build needs
`ENVIRONMENT=production` (it refuses to start as `development`), a non-empty
`API_SSL_FINGERPRINTS` in `.env.production` (it refuses to start with pinning on
and nothing to pin; see section 1) and, on Android, the signing key in
`android/key.properties`:

```bash
# Android APK
flutter build apk --release --obfuscate --split-debug-info=./build/debug-info --dart-define-from-file=.env.production

# Android App Bundle
flutter build appbundle --release --obfuscate --split-debug-info=./build/debug-info --dart-define-from-file=.env.production

# iOS
flutter build ios --release --obfuscate --split-debug-info=./build/debug-info --dart-define-from-file=.env.production
```

**Important:** Store the `debug-info` files securely. You'll need them to symbolicate crash reports.

### Symbolicating Crashes

To symbolicate a crash report, pass the symbols **file** for the crashing
architecture - `--split-debug-info` writes one per architecture, named
`app.<arch>.symbols`; `-d` does not take the directory:

```bash
flutter symbolize -i <crash-file> -d ./build/debug-info/app.android-arm64.symbols
```
```

---

### 3. Log Sanitization

Redaction already ships. Do not write a second sanitizer: a parallel policy
drifts from the one the logs actually go through.

<!-- symbol: lib/core/network/interceptors/api_logging_interceptor.dart ApiLoggingInterceptor -->
<!-- symbol: lib/core/network/interceptors/api_logging_interceptor.dart ApiLoggingInterceptor._sensitiveHeaderKeys -->
<!-- symbol: lib/core/network/interceptors/api_logging_interceptor.dart ApiLoggingInterceptor._sensitiveKeyFragments -->
<!-- symbol: lib/core/network/interceptors/api_logging_interceptor.dart ApiLoggingInterceptor._sensitiveKeysExact -->
<!-- symbol: lib/core/network/interceptors/api_logging_interceptor.dart ApiLoggingInterceptor.isSensitiveKey -->
<!-- symbol: lib/core/network/interceptors/api_logging_interceptor.dart ApiLoggingInterceptor.redactPath -->

#### What ships

`ApiLoggingInterceptor` (`lib/core/network/interceptors/api_logging_interceptor.dart`)
logs every request, response and error through `LoggingService`. It is installed
only when `ApiClient` is given a `LoggingService`, and logs nothing while
`AppConfig.enableHttpLogging` is false. Before anything reaches a sink it
replaces secrets with `***REDACTED***`:

| What | Rule |
|---|---|
| Headers | Exact, case-insensitive names in `_sensitiveHeaderKeys` (`authorization`, `cookie`, `x-api-key`, ...), then the key rules below as a second pass |
| Body, query and header keys | A key is normalised (lowercase, alphanumerics only, so `access_token`, `accessToken` and `X-Access-Token` all become `accesstoken`). It is redacted if it **contains** an entry of `_sensitiveKeyFragments` (`password`, `token`, `secret`, `jwt`, ...) or **equals** one in `_sensitiveKeysExact` (`pin`, `otp`, `cvv`, `session`, ...). Exact entries are the ones too short to be fragments: `pin` is inside `shipping` |
| Bodies | JSON maps and lists are walked recursively. A `String` body is decoded first; one that is not a JSON object or array (form-encoded, plain text, a bare scalar) is redacted wholesale. `FormData`, streams and other unwalkable values are redacted wholesale |
| Paths | `redactPath` applies the key rules to a query string embedded in the path (`/verify?token=...`) |

Redaction is decided by **key name only**, never by the shape of a value. A
secret carried under a key name none of the sets matches is logged.

A value in a **path segment** has no key name, so it is never redacted:
`/reset/<token>`, `/invite/<code>` or `/files/<signed-id>` reach the logs, and
the performance trace name, verbatim. Do not design routes that carry a secret
in the path. Send it in a header, in the body, or as a query parameter whose key
name is in the sensitive sets (`?token=...`) instead.

#### Extending it

Add the name to the matching set in `api_logging_interceptor.dart`:

- a non-standard credential header: `_sensitiveHeaderKeys` (lowercase), unless
  the key rules already catch it;
- a field name that should match anywhere inside a key: `_sensitiveKeyFragments`
  (normalised form: lowercase, no separators);
- a short name that would cause false positives as a fragment:
  `_sensitiveKeysExact`.

Then add a row for it to
`test/core/network/interceptors/api_logging_redaction_rules_test.dart`. That
file maps each rule to one key only that rule matches, and asserts how many
rules each set has, so a set that grows without a test row fails it.

Logs written outside this interceptor (`LoggingService.info(..., context: ...)`
from your own code) are **not** redacted. Keep credentials out of them at the
call site.

---

### 4. Android Release Signing

Release signing already ships. Set it up as described in
[Android deployment - Release signing](../../deployment/android-deployment.md#release-signing);
do not paste a different `build.gradle.kts` over the existing one.

#### What ships

`android/app/build.gradle.kts` reads `android/key.properties` (`storeFile`,
`storePassword`, `keyAlias`, `keyPassword`; `storeFile` relative to `android/`
or absolute) and signs `release` with it. It never falls back to the debug key:

| Situation | What the build does |
|---|---|
| No `android/key.properties` | Refuses every release `assemble`/`bundle`/`package` task ("Release signing is not configured ... Refusing.") |
| A key missing or blank | Fails, naming the missing keys |
| `storeFile` points at nothing | Fails, naming the resolved path |
| `-PallowUnsignedRelease=true` | Builds an unsigned release for local smoke tests; it cannot be installed or uploaded |

`android/.gitignore` already ignores `key.properties`, `**/*.jks` and
`**/*.keystore`. In CI,
[`deploy-android.yml`](../../../.github/workflows/deploy-android.yml) has a
commented-out "Setup Android keystore" step that writes the keystore and
`key.properties` from secrets; uncomment it once the secrets exist.

#### R8 / ProGuard

Nothing to switch on. The Flutter Gradle plugin already runs R8 on `release`
builds, with minification and resource shrinking, using
`proguard-android-optimize.txt` and Flutter's own keep rules. Pass
`-Pshrink=false` to turn it off for one build.

If a plugin or reflection-based code needs extra keep rules, create
`android/app/proguard-rules.pro`; the Flutter plugin adds it to the release
build automatically when it exists, so `build.gradle.kts` does not change.
For example, for a library loaded by reflection (substitute its package):

```proguard
# android/app/proguard-rules.pro
-keep class com.example.reflected.** { *; }
-dontwarn com.example.reflected.**
```

Add rules only for what an R8 build actually breaks; a release build that
crashes with `ClassNotFoundException` or `NoSuchMethodError` names the class
to keep.

---

### 5. Security Headers

Two kinds of header, delivered two different ways:

- **Content-Security-Policy** works in a `<meta http-equiv>` tag in
  `web/index.html` (except `frame-ancestors`, `report-uri` and `sandbox`,
  which only work as a response header).
- **`X-Frame-Options`, `X-Content-Type-Options`, `Permissions-Policy`** and
  `frame-ancestors` work **only as HTTP response headers** set by your server
  or host. In a `<meta>` tag browsers ignore them, so a meta-tag "clickjacking
  fix" protects nothing.

#### Step 1: A CSP that lets Flutter's renderer load

A default `flutter build web` does not load everything from your own origin:

- **CanvasKit** comes from `https://www.gstatic.com/flutter-canvaskit/<engine
  revision>/` (flutter_tools sets `FLUTTER_WEB_CANVASKIT_URL` unless the build
  passes `--no-web-resources-cdn`, which bundles it under `canvaskit/` on
  your origin instead);
- **fallback fonts** come from `https://fonts.gstatic.com/s/` (the engine's
  `fontFallbackBaseUrl` default), whichever way CanvasKit is served.

A policy of `default-src 'self'` with `font-src 'self' data:` blocks both, and
the app renders nothing. A starting point that allows them:

```html
<!-- web/index.html, inside <head> -->
<meta http-equiv="Content-Security-Policy"
      content="default-src 'self';
               script-src 'self' 'unsafe-inline' 'unsafe-eval' https://www.gstatic.com;
               style-src 'self' 'unsafe-inline';
               img-src 'self' data: https:;
               font-src 'self' data: https://fonts.gstatic.com;
               connect-src 'self' https://api.example.com https://www.gstatic.com https://fonts.gstatic.com;">
<meta name="referrer" content="strict-origin-when-cross-origin">
```

Replace `https://api.example.com` with your `BASE_URL` origin. If you build
with `--no-web-resources-cdn`, drop `https://www.gstatic.com`. Then tighten it
(`'unsafe-inline'`, `'unsafe-eval'`) only as far as your target browsers still
render the app - test the built app, not `flutter run`.

#### Step 2: The headers that must come from the server

Set these on your host, not in `index.html`. For example, Firebase Hosting
(`firebase.json`):

```json
{
  "hosting": {
    "headers": [
      {
        "source": "**",
        "headers": [
          { "key": "X-Frame-Options", "value": "DENY" },
          { "key": "X-Content-Type-Options", "value": "nosniff" },
          { "key": "Permissions-Policy", "value": "geolocation=(), microphone=(), camera=()" },
          { "key": "Content-Security-Policy", "value": "frame-ancestors 'none'" }
        ]
      }
    ]
  }
}
```

Netlify (`_headers`), Vercel (`vercel.json` `headers`) and any reverse proxy
have the same mechanism.

---

## High Priority Fixes

### 6. Network Security Config

#### Step 1: Create Network Security Config

The attribute is `cleartextTrafficPermitted`, and `<debug-overrides>` may hold
only `<trust-anchors>` - not a `<domain-config>`
([Network security configuration](https://developer.android.com/privacy-and-security/security-config)).

```xml
<!-- android/app/src/main/res/xml/network_security_config.xml -->
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <!-- Base configuration: Only allow HTTPS -->
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>

    <!-- Domain-specific configuration for production API -->
    <domain-config cleartextTrafficPermitted="false">
        <domain includeSubdomains="true">api.example.com</domain>
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </domain-config>
</network-security-config>
```

To let **debug builds only** reach a local server over plain HTTP, give the
debug source set its own copy of the file. Resources in `src/debug/res`
replace the ones in `src/main/res` in a debug build, so release keeps the
strict file above:

```xml
<!-- android/app/src/debug/res/xml/network_security_config.xml -->
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="false" />
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="false">localhost</domain>
        <domain includeSubdomains="false">10.0.2.2</domain>
    </domain-config>
</network-security-config>
```

#### Step 2: Update AndroidManifest.xml

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="flutter_starter"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="false"
        android:networkSecurityConfig="@xml/network_security_config"
        android:allowBackup="false"
        android:fullBackupContent="@xml/backup_rules"
        android:dataExtractionRules="@xml/data_extraction_rules">
        <!-- ... rest of manifest ... -->
    </application>
</manifest>
```

#### Step 3: Create Backup Rules

Two files, because Android reads a different one depending on the version the
app runs on ([Android 12 behavior changes](https://developer.android.com/about/versions/12/behavior-changes-12#backup-restore)):

- **Android 12 (API 31) and later** read `dataExtractionRules`, which has
  separate rules for cloud backup and for device-to-device (D2D) transfer.
  Once it is set, `fullBackupContent` is ignored there. Rules in the old
  format never affected D2D transfers, and on some manufacturers' devices
  `allowBackup="false"` stops cloud backup but not a D2D transfer - so the
  `<device-transfer>` excludes below are what actually keep data off a new
  phone.
- **Android 11 and earlier** read `fullBackupContent` (and `allowBackup`).

```xml
<!-- android/app/src/main/res/xml/data_extraction_rules.xml (Android 12+) -->
<?xml version="1.0" encoding="utf-8"?>
<data-extraction-rules>
    <cloud-backup>
        <exclude domain="sharedpref" path="." />
        <exclude domain="database" path="." />
        <exclude domain="file" path="." />
    </cloud-backup>
    <device-transfer>
        <exclude domain="sharedpref" path="." />
        <exclude domain="database" path="." />
        <exclude domain="file" path="." />
    </device-transfer>
</data-extraction-rules>
```

```xml
<!-- android/app/src/main/res/xml/backup_rules.xml (Android 11 and earlier) -->
<?xml version="1.0" encoding="utf-8"?>
<full-backup-content>
    <!-- Exclude all files from backup to protect sensitive data -->
    <exclude domain="sharedpref" path="." />
    <exclude domain="database" path="." />
    <exclude domain="file" path="." />
</full-backup-content>
```

Why this matters here: `flutter_secure_storage` keeps its ciphertext in
shared preferences and its key in the Android Keystore, which never leaves the
device. A restored copy of the ciphertext cannot be decrypted (the plugin's own
README names the `InvalidKeyException: Failed to unwrap key` this causes); with
`resetOnError` on, the plugin then wipes it and the user signs in again. The
plaintext preferences - the cached user, the unauthenticated HTTP cache - would
otherwise move to the new device as they are.

---

### 7. Root/Jailbreak Detection (FreeRASP)

To implement enterprise-grade Runtime Application Self-Protection (RASP), we utilize `freerasp` which operates at a lower level than typical check plugins.

#### Step 1: Add freerasp and rename the templates

`freerasp` is not a default dependency. Adding it links freeRASP's
closed-source SDK (`TalsecSecurity-Community-Flutter`, from a vendor Maven
registry) into every Android build, and with it - whether or not RASP is
started - the merged manifest gains `READ_GSERVICES` (from
`fingerprint-android`), `USE_BIOMETRIC` (from `androidx.biometric`),
`ACCESS_WIFI_STATE` and `RECEIVE_BOOT_COMPLETED` (from `truetime-android`),
and `<queries>` for the SMS-received and outgoing-call intents. Declare those
in Play's data-safety form. Check the list against your own build's
`build/app/outputs/logs/manifest-merger-release-report.txt`, since it moves
with the freerasp version.

```bash
flutter pub add freerasp:8.2.4   # exactly the version the template was checked against
(cd lib/core/security/infrastructure && mv freerasp_service_impl.dart.template freerasp_service_impl.dart)
(cd test/core/security/infrastructure && for f in freerasp_*.dart.template; do mv "$f" "${f%.template}"; done)
```

Then edit the placeholder `TalsecConfig` inside
[`freerasp_service_impl.dart.template`](../../../lib/core/security/infrastructure/freerasp_service_impl.dart.template),
renamed as above (package names, signing cert hashes, team id, email,
stores). The class **`FreeRaspServiceImpl`** already implements
[`IRaspService`](../../../lib/core/security/i_rasp_service.dart).

#### Step 2: Override `raspServiceProvider` and start protection

[`raspServiceProvider`](../../../lib/core/security/rasp_providers.dart) defaults to [`NoOpRaspService`](../../../lib/core/security/noop_rasp_service.dart). When you are ready to ship real RASP, override it in `createAppContainer` in `lib/main.dart` - the one container the app runs on - by adding it to the list that already holds `authModuleOverrides`:

```dart
// lib/main.dart
import 'package:flutter_starter/core/security/infrastructure/freerasp_service_impl.dart';
import 'package:flutter_starter/core/security/rasp_providers.dart';

ProviderContainer createAppContainer({
  List<Override> overrides = const <Override>[],
}) {
  return ProviderContainer(
    retry: _neverRetry,
    overrides: <Override>[
      ...authModuleOverrides,
      raspServiceProvider.overrideWithValue(FreeRaspServiceImpl()),
      ...overrides,
    ],
  );
}
```

Then start protection in `bootstrap()`, right after `final container = createContainer();`:

```dart
final rasp = container.read(raspServiceProvider);
await rasp.startProtection();
rasp.onThreatDetected.listen((threat) {
  // Map SecurityThreat (privilegedAccess, emulator, debugger, ...) to policy
});
```

Do **not** build a second `ProviderContainer` for this. `createAppContainer`
is what binds `authModuleOverrides` - the token refresher and the session
termination sink - and `_neverRetry`; a container built without them loses 401
refresh and forced logout without any error.

<!-- symbol: lib/main.dart createAppContainer -->
<!-- symbol: lib/features/auth/di/auth_providers.dart authModuleOverrides -->

There is **no** `device_security.dart` in this starter; wire threat handling in your own module if you need blocking UI or forced logout.

#### What the adapter forwards

`FreeRaspServiceImpl` forwards **every** detection freerasp 8.2.4 reports - the exact version step 1 adds, and the only one the adapter was checked against. Moving to another version means re-checking `ThreatCallback`, as below. Each freeRASP `Threat` reaches `onThreatDetected` as the `SecurityThreat` below, and malware, which freeRASP delivers on its own callback rather than as a `Threat`, arrives as `SecurityThreat.malware`. No detection is deliberately ignored. Once only 10 of the 23 callbacks were set, and freeRASP drops a detection whose callback is null without logging it.

| freeRASP callback | `SecurityThreat` | Platforms | Kind |
|---|---|---|---|
| `onAppIntegrity` | `tampered` | both | attack |
| `onObfuscationIssues` | `tampered` | both | build posture |
| `onDebug` | `debugger` | both | attack |
| `onHooks` | `privilegedAccess` | both | attack |
| `onPrivilegedAccess` | `privilegedAccess` | both | attack |
| `onSimulator` | `emulator` | both | attack |
| `onUnofficialStore` | `unofficialStore` | both | attack |
| `onDeviceBinding` | `unknown` | both | attack |
| `onDeviceID` | `unknown` | iOS | informational |
| `onSecureHardwareNotAvailable` | `unknown` | both | device posture |
| `onMalware` | `malware` | Android | attack |
| `onBootloader` | `unlockedBootloader` | Android | attack |
| `onAutomation` | `automation` | Android | attack |
| `onMultiInstance` | `multiInstance` | Android | attack |
| `onTimeSpoofing` | `timeSpoofing` | both | attack |
| `onLocationSpoofing` | `locationSpoofing` | Android | attack |
| `onScreenshot` | `screenshot` | both | user action |
| `onScreenRecording` | `screenRecording` | both | user action |
| `onPasscode` | `passcodeNotSet` | both | device posture |
| `onDevMode` | `developerMode` | Android | device posture |
| `onADBEnabled` | `adbEnabled` | Android | device posture |
| `onSystemVPN` | `systemVpn` | both | device posture |
| `onUnsecureWiFi` | `unsecureWiFi` | Android | device posture |

"Kind" is guidance for your policy, not something the adapter acts on. A **device posture** or **user action** signal fires on many legitimate devices: a developer phone has developer options and ADB on, and a corporate phone runs a system VPN. Forcing a logout on those locks out real users. Log them or warn, and save blocking for the **attack** rows.

`test/core/security/infrastructure/freerasp_service_impl_test.dart.template` (renamed in step 1) drives each of freeRASP's `Threat` values through its mocked platform channel and fails if one is neither forwarded as this table says nor listed as deliberately ignored. A freerasp upgrade that adds a `Threat` value therefore fails `flutter test` until someone maps it, and the exhaustive `switch` in `FreeRaspServiceImpl.securityThreatFor` stops compiling first. A new `Threat` gets a row here, too.

That guard covers new `Threat` values **only**. freeRASP also delivers some detections on a callback of their own (`onMalware` is one), and every `ThreatCallback` parameter is optional: a version that adds such a callback still compiles with the adapter leaving it null, and freeRASP then drops that detection without logging it. On every freerasp upgrade, compare `ThreatCallback`'s parameters with the ones `_start()` passes, by hand.

### 8. Session management (blueprint)

Not in this repo. Full template (session timer + lifecycle sketch): **[Security blueprints → Session management](./blueprints.md#session-management)**.

## Compliance Features

### 9. GDPR consent (blueprint)

Not in this repo. Full template (consent manager + screen): **[Security blueprints → GDPR](./blueprints.md#gdpr-and-consent-ui)**.

---

## Testing Your Security Implementation

### Test SSL Pinning

```dart
// test/security/ssl_pinning_test.dart
void main() {
  test('SSL pinning should reject invalid certificates', () async {
    // Test with invalid certificate
    // Should throw exception
  });
}
```

### Test Log Sanitization

The redaction rules are pinned by
`test/core/network/interceptors/api_logging_redaction_rules_test.dart`. This is
its response-side case, verbatim:

<!-- test-excerpt: test/core/network/interceptors/api_logging_redaction_rules_test.dart -->
```dart
  test('criterion 2: onResponse never logs an access_token value', () {
    Map<String, dynamic>? context;
    when(
      () => logging.info(any(), context: any(named: 'context')),
    ).thenAnswer((invocation) {
      context = invocation.namedArguments[#context] as Map<String, dynamic>?;
    });

    interceptor.onResponse(
      Response<dynamic>(
        requestOptions: RequestOptions(path: '/auth/login', method: 'POST'),
        statusCode: 200,
        data: {'access_token': 'T0KEN-VALUE', 'user': 'u'},
      ),
      _ResponseHandler(),
    );

    expect(context, isNotNull);
    expect(context.toString(), isNot(contains('T0KEN-VALUE')));
    expect((context!['body'] as Map)['access_token'], _redacted);
  });
```

---

## Next Steps

1. **Prioritize:** Start with critical fixes (SSL pinning, obfuscation, logging)
2. **Test:** Thoroughly test each implementation
3. **Document:** Update your internal documentation
4. **Monitor:** Set up security monitoring
5. **Review:** Schedule regular security audits

---

**Remember:** Security is an ongoing process, not a one-time task. Regularly review and update your security measures.


