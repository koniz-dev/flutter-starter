# Security Implementation Guide

This guide provides step-by-step instructions and code examples for implementing the security recommendations from the [Security Audit Report](./audit.md).

---

## RASP / FreeRASP (optional)

The `freerasp` package is listed in `pubspec.yaml` for teams that want runtime app shielding. By default the app uses a **no-op** implementation via [`raspServiceProvider`](../../../lib/core/security/rasp_providers.dart) (`NoOpRaspService`), so nothing is enforced until you override the provider with a concrete implementation (for example `FreeRaspServiceImpl` in `lib/core/security/infrastructure/freerasp_service_impl.dart`). Enabling real RASP requires FreeRASP configuration, platform setup, and usually a commercial agreement—see the [FreeRASP documentation](https://docs.talsec.app/freerasp).

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
(`lib/core/network/api_client.dart:75-101`). The `HttpClient` is constructed
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
(`lib/core/config/app_config.dart:110-141`):

| Setting | Env variable | Default |
|---|---|---|
| `AppConfig.apiSslFingerprints` | `API_SSL_FINGERPRINTS` | empty list |
| `AppConfig.enableSslPinning` | `ENABLE_SSL_PINNING` | `true` in staging and production; in development `true` once `API_SSL_FINGERPRINTS` is set, `false` otherwise |

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

`.env.example:34-39` already carries both keys, empty.

#### Step 3: Verify it is actually on

Pinning is decided by `SslPinning.createAdapter()` in
`lib/core/network/ssl_pinning.dart`, which `ApiClient` calls when it builds its
transport. It installs the pinned adapter only when `ENABLE_SSL_PINNING` is on
**and** `API_SSL_FINGERPRINTS` is non-empty.

<!-- symbol: lib/core/network/ssl_pinning.dart SslPinning -->

Requesting pinning with no fingerprints does not fail quietly:
`createAdapter()` logs `SSL PINNING MISCONFIGURED: ...` and trips an assertion
in debug builds. A release build still runs unpinned, so the log line is all
you get there. `AppConfig.printConfig()` prints `SSL Pinning Requested`,
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
# SslPinning returns no adapter and the release falls back to the system
# trust store, so refuse to build instead of shipping unpinned.
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
      
      - name: Build APK
        run: |
          flutter build apk --release \
            --obfuscate \
            --split-debug-info=./build/debug-info \
            --dart-define=ENVIRONMENT=production \
            --dart-define=BASE_URL=${{ secrets.BASE_URL }} \
            --dart-define=API_SSL_FINGERPRINTS="${{ secrets.API_SSL_FINGERPRINTS }}"
      
      - name: Upload Debug Info
        uses: actions/upload-artifact@v7
        with:
          name: debug-info
          path: build/debug-info/
          retention-days: 365
      
      - name: Upload APK
        uses: actions/upload-artifact@v7
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

Always use obfuscation for production builds:

```bash
# Android APK
flutter build apk --release --obfuscate --split-debug-info=./build/debug-info

# Android App Bundle
flutter build appbundle --release --obfuscate --split-debug-info=./build/debug-info

# iOS
flutter build ios --release --obfuscate --split-debug-info=./build/debug-info
```

**Important:** Store the `debug-info` files securely. You'll need them to symbolicate crash reports.

### Symbolicating Crashes

To symbolicate a crash report:

```bash
flutter symbolize -i <crash-file> -d ./build/debug-info/
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
<!-- symbol: lib/core/network/interceptors/api_logging_interceptor.dart ApiLoggingInterceptor._isSensitiveKey -->
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

#### Step 1: Update web/index.html

```html
<!-- web/index.html -->
<!DOCTYPE html>
<html>
<head>
  <base href="$FLUTTER_BASE_HREF">

  <meta charset="UTF-8">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <meta name="description" content="A new Flutter project.">

  <!-- Security Headers -->
  <meta http-equiv="Content-Security-Policy" 
        content="default-src 'self'; 
                 script-src 'self' 'unsafe-inline' 'unsafe-eval'; 
                 style-src 'self' 'unsafe-inline'; 
                 img-src 'self' data: https:; 
                 connect-src 'self' https://api.example.com;
                 font-src 'self' data:;">
  
  <meta http-equiv="X-Frame-Options" content="DENY">
  <meta http-equiv="X-Content-Type-Options" content="nosniff">
  <meta name="referrer" content="strict-origin-when-cross-origin">
  <meta http-equiv="Permissions-Policy" 
        content="geolocation=(), microphone=(), camera=()">

  <!-- iOS meta tags & icons -->
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="flutter_starter">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">

  <!-- Favicon -->
  <link rel="icon" type="image/png" href="favicon.png"/>

  <title>flutter_starter</title>
  <link rel="manifest" href="manifest.json">
</head>
<body>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
```

**Note:** Adjust CSP policy based on your actual requirements. The above is a starting point.

---

## High Priority Fixes

### 6. Network Security Config

#### Step 1: Create Network Security Config

```xml
<!-- android/app/src/main/res/xml/network_security_config.xml -->
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <!-- Base configuration: Only allow HTTPS -->
    <base-config cleartextTraffic="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>
    
    <!-- Domain-specific configuration for production API -->
    <domain-config cleartextTraffic="false">
        <domain includeSubdomains="true">api.example.com</domain>
        <trust-anchors>
            <certificates src="system" />
            <!-- Add pinned certificate if needed -->
        </trust-anchors>
    </domain-config>
    
    <!-- Debug overrides: Allow cleartext for localhost only -->
    <debug-overrides>
        <domain-config cleartextTraffic="true">
            <domain includeSubdomains="true">localhost</domain>
            <domain includeSubdomains="true">127.0.0.1</domain>
            <domain includeSubdomains="true">10.0.2.2</domain>
        </domain-config>
    </debug-overrides>
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
        android:fullBackupContent="@xml/backup_rules">
        <!-- ... rest of manifest ... -->
    </application>
</manifest>
```

#### Step 3: Create Backup Rules

```xml
<!-- android/app/src/main/res/xml/backup_rules.xml -->
<?xml version="1.0" encoding="utf-8"?>
<full-backup-content>
    <!-- Exclude all files from backup to protect sensitive data -->
    <exclude domain="sharedpref" path="." />
    <exclude domain="database" path="." />
    <exclude domain="file" path="." />
</full-backup-content>
```

---

### 7. Root/Jailbreak Detection (FreeRASP)

To implement enterprise-grade Runtime Application Self-Protection (RASP), we utilize `freerasp` which operates at a lower level than typical check plugins.

#### Step 1: Initialize RASP Service

Ensure `freerasp` is configured with your production hashes and connected to the `raspServiceProvider` in `lib/core/security/`. 

Edit the placeholder `TalsecConfig` inside [`lib/core/security/infrastructure/freerasp_service_impl.dart`](../../../lib/core/security/infrastructure/freerasp_service_impl.dart) (package names, signing cert hashes, team id, email, stores). The class **`FreeRaspServiceImpl`** already implements [`IRaspService`](../../../lib/core/security/i_rasp_service.dart).

#### Step 2: Override `raspServiceProvider` and start protection

[`raspServiceProvider`](../../../lib/core/security/rasp_providers.dart) defaults to [`NoOpRaspService`](../../../lib/core/security/noop_rasp_service.dart). After you are ready to ship real RASP, override it when you build the [`ProviderContainer`](https://pub.dev/documentation/flutter_riverpod/latest/flutter_riverpod/ProviderContainer-class.html) in `main.dart`, then start listening:

```dart
// lib/main.dart — excerpt after WidgetsFlutterBinding.ensureInitialized()
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/security/infrastructure/freerasp_service_impl.dart';
import 'package:flutter_starter/core/security/rasp_providers.dart';

final container = ProviderContainer(
  overrides: [
    raspServiceProvider.overrideWithValue(FreeRaspServiceImpl()),
  ],
);

final rasp = container.read(raspServiceProvider);
await rasp.startProtection();
rasp.onThreatDetected.listen((threat) {
  // Map SecurityThreat (privilegedAccess, emulator, debugger, …) to policy
});
```

Use the same `container` for `UncontrolledProviderScope` / `runApp` so the override applies app-wide.

There is **no** `device_security.dart` in this starter; wire threat handling in your own module if you need blocking UI or forced logout.

#### What the adapter forwards

`FreeRaspServiceImpl` forwards **every** detection the pinned freerasp (8.2.4) reports. Each freeRASP `Threat` reaches `onThreatDetected` as the `SecurityThreat` below, and malware, which freeRASP delivers on its own callback rather than as a `Threat`, arrives as `SecurityThreat.malware`. No detection is deliberately ignored. Once only 10 of the 23 callbacks were set, and freeRASP drops a detection whose callback is null without logging it.

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

`test/core/security/infrastructure/freerasp_service_impl_test.dart` drives each of freeRASP's `Threat` values through its mocked platform channel and fails if one is neither forwarded as this table says nor listed as deliberately ignored. A freerasp upgrade that adds a detection therefore fails `flutter test` until someone maps it, and the exhaustive `switch` in `FreeRaspServiceImpl.securityThreatFor` stops compiling first. A new `Threat` gets a row here, too.

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


