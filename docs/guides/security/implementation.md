# Security Implementation Guide

This guide provides step-by-step instructions and code examples for implementing the security recommendations from the [Security Audit Report](./audit.md).

---

## RASP / FreeRASP (optional)

The `freerasp` package is listed in `pubspec.yaml` for teams that want runtime app shielding. By default the app uses a **no-op** implementation via [`raspServiceProvider`](../../../lib/core/security/rasp_providers.dart) (`NoOpRaspService`), so nothing is enforced until you override the provider with a concrete implementation (for example `FreeRaspServiceImpl` in `lib/core/security/infrastructure/freerasp_service_impl.dart`). Enabling real RASP requires FreeRASP configuration, platform setup, and usually a commercial agreement—see the [FreeRASP documentation](https://docs.talsec.app/freerasp).

---

## Table of Contents

1. [Critical Fixes](#critical-fixes)
   - [SSL Certificate Pinning](#1-ssl-certificate-pinning)
   - [Code Obfuscation](#2-code-obfuscation)
   - [Log Sanitization](#3-log-sanitization)
   - [Android Release Signing](#4-android-release-signing)
   - [Security Headers](#5-security-headers)

2. [High Priority Fixes](#high-priority-fixes)
   - [Network Security Config](#6-network-security-config)
   - [Root/Jailbreak Detection](#7-rootjailbreak-detection)
   - [Session Management](#8-session-management)

3. [Compliance Features](#compliance-features)
   - [GDPR Consent Management](#9-gdpr-consent-management)

---

## Conventions (shipped code vs blueprints)

- **In this repository:** Prefer paths that exist under `lib/` today (see [Contracts map](../../architecture/contracts-map.md)).
- **Blueprints:** Optional modules (session timeout, GDPR UI, extra SSL snippets) live in **[blueprints.md](./blueprints.md)** — not in `lib/`. Use as templates only.

## Critical Fixes

### 1. SSL Certificate Pinning

#### Step 1: Add Dependency

```yaml
# pubspec.yaml
dependencies:
  dio_certificate_pinning: ^2.2.0
```

#### Step 2: Extract Certificate Fingerprint

```bash
# For your API server
openssl s_client -servername api.example.com -connect api.example.com:443 < /dev/null | \
  openssl x509 -fingerprint -sha256 -noout -in /dev/stdin

# Output example:
# SHA256 Fingerprint=AA:BB:CC:DD:EE:FF:...
```

#### Step 3: Update ApiClient

```dart
// lib/core/network/api_client.dart
import 'package:dio/dio.dart';
import 'package:dio_certificate_pinning/dio_certificate_pinning.dart';
import 'package:flutter_starter/core/config/app_config.dart';
// ... other imports

class ApiClient {
  // ... existing code ...

  static Dio _createDio(
    StorageService storageService,
    SecureStorageService secureStorageService,
    AuthInterceptor authInterceptor,
  ) {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl + ApiEndpoints.apiVersion,
        connectTimeout: Duration(seconds: AppConfig.apiConnectTimeout),
        receiveTimeout: Duration(seconds: AppConfig.apiReceiveTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add certificate pinning for production
    if (AppConfig.isProduction) {
      final fingerprints = _getCertificateFingerprints();
      if (fingerprints.isNotEmpty) {
        dio.httpClientAdapter = CertificatePinningAdapter(
          allowedSHAFingerprints: fingerprints,
        );
      }
    }

    // Add interceptors - ErrorInterceptor must be first
    dio.interceptors.addAll([
      ErrorInterceptor(),
      authInterceptor,
      if (AppConfig.enableLogging) LoggingInterceptor(),
    ]);

    return dio;
  }

  /// Get certificate fingerprints from environment
  /// Format: "FINGERPRINT1,FINGERPRINT2" (comma-separated, no spaces)
  static List<String> _getCertificateFingerprints() {
    final fingerprints = EnvConfig.get('CERTIFICATE_FINGERPRINTS');
    if (fingerprints.isEmpty) {
      return [];
    }
    return fingerprints
        .split(',')
        .map((f) => f.trim().replaceAll(':', '').toUpperCase())
        .where((f) => f.isNotEmpty)
        .toList();
  }

  // ... rest of existing code ...
}
```

#### Step 4: Add to Environment Config

```bash
# .env.example
CERTIFICATE_FINGERPRINTS=AA:BB:CC:DD:EE:FF:11:22:33:44:55:66:77:88:99:00:AA:BB:CC:DD:EE:FF:11:22:33:44:55:66:77:88:99:00,BB:CC:DD:EE:FF:AA:11:22:33:44:55:66:77:88:99:00:AA:BB:CC:DD:EE:FF:11:22:33:44:55:66:77:88:99:00
```

**Note:** Store actual fingerprints securely. Never commit real fingerprints to git.

---

### 2. Code Obfuscation

#### Step 1: Update Build Scripts

Create a build script:

```bash
# scripts/ci/build_release.sh
#!/bin/bash

ENVIRONMENT=${1:-production}
BUILD_TYPE=${2:-apk}  # apk, appbundle, ios

echo "Building $BUILD_TYPE for $ENVIRONMENT with obfuscation..."

if [ "$BUILD_TYPE" = "apk" ]; then
  flutter build apk --release \
    --obfuscate \
    --split-debug-info=./build/debug-info \
    --dart-define=ENVIRONMENT=$ENVIRONMENT \
    --dart-define=BASE_URL=https://api.example.com \
    --dart-define=CERTIFICATE_FINGERPRINTS="$CERTIFICATE_FINGERPRINTS"
elif [ "$BUILD_TYPE" = "appbundle" ]; then
  flutter build appbundle --release \
    --obfuscate \
    --split-debug-info=./build/debug-info \
    --dart-define=ENVIRONMENT=$ENVIRONMENT \
    --dart-define=BASE_URL=https://api.example.com \
    --dart-define=CERTIFICATE_FINGERPRINTS="$CERTIFICATE_FINGERPRINTS"
elif [ "$BUILD_TYPE" = "ios" ]; then
  flutter build ios --release \
    --obfuscate \
    --split-debug-info=./build/debug-info \
    --dart-define=ENVIRONMENT=$ENVIRONMENT \
    --dart-define=BASE_URL=https://api.example.com \
    --dart-define=CERTIFICATE_FINGERPRINTS="$CERTIFICATE_FINGERPRINTS"
fi

echo "Build complete. Debug info saved to ./build/debug-info/"
echo "⚠️  IMPORTANT: Store debug-info files securely for crash symbolication!"
```

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
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
      
      - name: Build APK
        run: |
          flutter build apk --release \
            --obfuscate \
            --split-debug-info=./build/debug-info \
            --dart-define=ENVIRONMENT=production \
            --dart-define=BASE_URL=${{ secrets.BASE_URL }} \
            --dart-define=CERTIFICATE_FINGERPRINTS="${{ secrets.CERTIFICATE_FINGERPRINTS }}"
      
      - name: Upload Debug Info
        uses: actions/upload-artifact@v3
        with:
          name: debug-info
          path: build/debug-info/
          retention-days: 365
      
      - name: Upload APK
        uses: actions/upload-artifact@v3
        with:
          name: app-release
          path: build/app/outputs/flutter-apk/app-release.apk
```

#### Step 3: Update Documentation

Add to `docs/guides/build-and-deploy.md`:

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

#### Step 1: Create Log Sanitizer

```dart
// lib/core/utils/log_sanitizer.dart
import 'dart:convert';

/// Utility for sanitizing sensitive data from logs
class LogSanitizer {
  LogSanitizer._();

  /// List of keys that contain sensitive data
  static const List<String> _sensitiveKeys = [
    'password',
    'token',
    'access_token',
    'refresh_token',
    'authorization',
    'auth',
    'api_key',
    'apikey',
    'secret',
    'credit_card',
    'card_number',
    'cvv',
    'ssn',
    'social_security_number',
    'email', // Optional: may want to redact emails too
  ];

  /// Sensitive endpoint patterns
  static const List<String> _sensitiveEndpoints = [
    '/login',
    '/register',
    '/password',
    '/auth',
    '/token',
  ];

  /// Sanitize a map by redacting sensitive keys
  static Map<String, dynamic> sanitizeMap(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};
    
    for (final entry in data.entries) {
      final key = entry.key.toLowerCase();
      final isSensitive = _sensitiveKeys.any(
        (sensitiveKey) => key.contains(sensitiveKey.toLowerCase()),
      );
      
      if (isSensitive) {
        sanitized[entry.key] = '***REDACTED***';
      } else if (entry.value is Map) {
        sanitized[entry.key] = sanitizeMap(entry.value as Map<String, dynamic>);
      } else if (entry.value is List) {
        sanitized[entry.key] = _sanitizeList(entry.value as List);
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    
    return sanitized;
  }

  /// Sanitize a list
  static List<dynamic> _sanitizeList(List<dynamic> list) {
    return list.map((item) {
      if (item is Map) {
        return sanitizeMap(item as Map<String, dynamic>);
      } else if (item is List) {
        return _sanitizeList(item);
      }
      return item;
    }).toList();
  }

  /// Sanitize headers
  static Map<String, dynamic> sanitizeHeaders(Map<String, dynamic> headers) {
    final sanitized = Map<String, dynamic>.from(headers);
    
    for (final key in _sensitiveKeys) {
      if (sanitized.containsKey(key)) {
        sanitized[key] = '***REDACTED***';
      }
      // Case-insensitive check
      final headerKey = sanitized.keys.firstWhere(
        (k) => k.toLowerCase() == key.toLowerCase(),
        orElse: () => '',
      );
      if (headerKey.isNotEmpty) {
        sanitized[headerKey] = '***REDACTED***';
      }
    }
    
    // Special handling for Authorization header
    if (sanitized.containsKey('Authorization')) {
      final auth = sanitized['Authorization'] as String?;
      if (auth != null && auth.startsWith('Bearer ')) {
        sanitized['Authorization'] = 'Bearer ***REDACTED***';
      }
    }
    
    return sanitized;
  }

  /// Check if an endpoint is sensitive
  static bool isSensitiveEndpoint(String path) {
    return _sensitiveEndpoints.any(
      (endpoint) => path.toLowerCase().contains(endpoint.toLowerCase()),
    );
  }

  /// Sanitize request/response data for sensitive endpoints
  static dynamic sanitizeData(dynamic data, String? path) {
    if (path != null && isSensitiveEndpoint(path)) {
      return '***REDACTED (sensitive endpoint)***';
    }
    
    if (data is Map) {
      return sanitizeMap(data as Map<String, dynamic>);
    } else if (data is List) {
      return _sanitizeList(data);
    } else if (data is String) {
      // Check if string contains JSON
      try {
        final json = jsonDecode(data);
        if (json is Map) {
          return jsonEncode(sanitizeMap(json as Map<String, dynamic>));
        }
      } catch (_) {
        // Not JSON, return as is
      }
    }
    
    return data;
  }
}
```

#### Step 2: API logging (`ApiLoggingInterceptor`)

The starter already ships **`ApiLoggingInterceptor`** in `lib/core/network/interceptors/api_logging_interceptor.dart`. It uses **`LoggingService`** (not `debugPrint`) and applies built-in redaction for common sensitive headers and JSON keys when `AppConfig.enableHttpLogging` is true.

- Extend **`_sanitizeHeaders`** / **`_sanitizeJson`** in that file for custom token header names or payload fields.
- Reuse **`LogSanitizer`** from Step 1 where you want one shared policy for logs outside this interceptor.

---

### 4. Android Release Signing

#### Step 1: Create Keystore

```bash
# Generate keystore (run once, store securely)
keytool -genkey -v -keystore android/app/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload \
  -storepass <your-keystore-password> \
  -keypass <your-key-password> \
  -dname "CN=Your Company, OU=Development, O=Your Company, L=City, ST=State, C=US"
```

#### Step 2: Create keystore.properties (DO NOT COMMIT)

```properties
# android/keystore.properties (add to .gitignore)
storePassword=<your-keystore-password>
keyPassword=<your-key-password>
keyAlias=upload
storeFile=upload-keystore.jks
```

#### Step 3: Update build.gradle.kts

```kotlin
// android/app/build.gradle.kts
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Load keystore properties
val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.example.flutter_starter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.flutter_starter"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
```

#### Step 4: Create ProGuard Rules

```proguard
# android/app/proguard-rules.pro
# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep secure storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# Keep JSON serialization
-keepattributes Signature
-keepattributes *Annotation*
-keep class * implements java.io.Serializable { *; }
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep your models (adjust package name)
-keep class com.example.flutter_starter.** { *; }
```

#### Step 5: Update .gitignore

```gitignore
# Add to .gitignore
*.jks
*.keystore
keystore.properties
upload-keystore.jks
```

#### Step 6: CI/CD Configuration

For CI/CD, use environment variables or secrets:

```kotlin
// Alternative: Use environment variables in CI/CD
signingConfigs {
    create("release") {
        keyAlias = System.getenv("KEY_ALIAS") ?: keystoreProperties["keyAlias"] as String?
        keyPassword = System.getenv("KEY_PASSWORD") ?: keystoreProperties["keyPassword"] as String?
        storeFile = file(System.getenv("KEYSTORE_FILE") ?: keystoreProperties["storeFile"] as String)
        storePassword = System.getenv("KEYSTORE_PASSWORD") ?: keystoreProperties["storePassword"] as String?
    }
}
```

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

### 8. Session management (blueprint)

Not in this repo. Full template (session timer + lifecycle sketch): **[Security blueprints → Session management](./blueprints.md#session-management)**.

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

```dart
// test/core/utils/log_sanitizer_test.dart
void main() {
  test('should redact sensitive keys', () {
    final data = {'password': 'secret123', 'username': 'user'};
    final sanitized = LogSanitizer.sanitizeMap(data);
    expect(sanitized['password'], '***REDACTED***');
    expect(sanitized['username'], 'user');
  });
}
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


