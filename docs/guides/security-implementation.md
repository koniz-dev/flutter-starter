# Security Implementation Guide

This guide provides step-by-step instructions and code examples for implementing the security recommendations from the [Security Audit Report](security-audit.md).

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
# scripts/build_release.sh
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
chmod +x scripts/build_release.sh
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

#### Step 2: Update Logging Interceptor

```dart
// lib/core/network/interceptors/logging_interceptor.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_starter/core/config/app_config.dart';
import 'package:flutter_starter/core/utils/log_sanitizer.dart';

/// Interceptor for logging HTTP requests and responses
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode && AppConfig.enableHttpLogging) {
      debugPrint('REQUEST[${options.method}] => PATH: ${options.path}');
      
      // Sanitize headers
      final sanitizedHeaders = LogSanitizer.sanitizeHeaders(options.headers);
      debugPrint('Headers: $sanitizedHeaders');
      
      // Sanitize data
      if (options.data != null) {
        final sanitizedData = LogSanitizer.sanitizeData(
          options.data,
          options.path,
        );
        debugPrint('Data: $sanitizedData');
      }
      
      if (options.queryParameters.isNotEmpty) {
        final sanitizedParams = LogSanitizer.sanitizeMap(
          options.queryParameters as Map<String, dynamic>,
        );
        debugPrint('QueryParams: $sanitizedParams');
      }
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (kDebugMode && AppConfig.enableHttpLogging) {
      debugPrint(
        'RESPONSE[${response.statusCode}] => '
        'PATH: ${response.requestOptions.path}',
      );
      
      // Sanitize response data
      final sanitizedData = LogSanitizer.sanitizeData(
        response.data,
        response.requestOptions.path,
      );
      debugPrint('Data: $sanitizedData');
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode && AppConfig.enableHttpLogging) {
      debugPrint(
        'ERROR[${err.response?.statusCode}] => '
        'PATH: ${err.requestOptions.path}',
      );
      debugPrint('Message: ${err.message}');
      
      if (err.response?.data != null) {
        final sanitizedData = LogSanitizer.sanitizeData(
          err.response?.data,
          err.requestOptions.path,
        );
        debugPrint('Error Data: $sanitizedData');
      }
    }
    super.onError(err, handler);
  }
}
```

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

### 7. Root/Jailbreak Detection

#### Step 1: Add Dependency

```yaml
# pubspec.yaml
dependencies:
  root_jailbreak: ^1.0.0
```

#### Step 2: Create Device Security Service

```dart
// lib/core/security/device_security.dart
import 'package:root_jailbreak/root_jailbreak.dart';
import 'package:flutter_starter/core/config/app_config.dart';

/// Service for checking device security status
class DeviceSecurity {
  DeviceSecurity._();

  /// Check if device is secure (not rooted/jailbroken)
  static Future<bool> isDeviceSecure() async {
    try {
      final isRooted = await RootJailbreak.isRooted;
      final isJailbroken = await RootJailbreak.isJailbroken;
      return !isRooted && !isJailbroken;
    } catch (e) {
      // If check fails, assume device is secure to avoid false positives
      // Log the error for monitoring
      return true;
    }
  }

  /// Check device security and throw exception if insecure
  static Future<void> checkDeviceSecurity() async {
    if (!AppConfig.isProduction) {
      // Skip check in development
      return;
    }

    final isSecure = await isDeviceSecure();
    if (!isSecure) {
      throw DeviceSecurityException(
        'Device is rooted or jailbroken. App cannot run on insecure devices.',
      );
    }
  }
}

/// Exception thrown when device security check fails
class DeviceSecurityException implements Exception {
  final String message;
  DeviceSecurityException(this.message);

  @override
  String toString() => 'DeviceSecurityException: $message';
}
```

#### Step 3: Check on App Start

```dart
// lib/main.dart
import 'package:flutter_starter/core/security/device_security.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check device security in production
  if (AppConfig.isProduction) {
    try {
      await DeviceSecurity.checkDeviceSecurity();
    } on DeviceSecurityException {
      // Handle insecure device
      // Option 1: Show error and exit
      // Option 2: Log and continue with limited functionality
      runApp(const SecurityWarningApp());
      return;
    }
  }

  // ... rest of initialization ...
}
```

---

### 8. Session Management

#### Step 1: Create Session Manager

```dart
// lib/core/security/session_manager.dart
import 'dart:async';
import 'package:flutter_starter/core/storage/secure_storage_service.dart';
import 'package:flutter_starter/core/constants/app_constants.dart';
import 'package:flutter_starter/features/auth/domain/repositories/auth_repository.dart';

/// Manages user session timeout and activity tracking
class SessionManager {
  SessionManager({
    required this.secureStorageService,
    required this.authRepository,
  });

  final SecureStorageService secureStorageService;
  final AuthRepository authRepository;

  Timer? _sessionTimer;
  static const Duration sessionTimeout = Duration(hours: 24);
  DateTime? _lastActivity;

  /// Initialize session manager
  void initialize() {
    resetSessionTimer();
    _lastActivity = DateTime.now();
  }

  /// Reset session timer (call on user activity)
  void resetSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(sessionTimeout, () {
      _handleSessionTimeout();
    });
    _lastActivity = DateTime.now();
  }

  /// Handle user activity (call from app lifecycle or user interactions)
  void onUserActivity() {
    resetSessionTimer();
  }

  /// Handle session timeout
  Future<void> _handleSessionTimeout() async {
    // Check if user is still authenticated
    final token = await secureStorageService.getString(AppConstants.tokenKey);
    if (token == null) {
      return; // Already logged out
    }

    // Logout user
    await authRepository.logout();
    
    // Optionally notify user or trigger re-authentication
    // You can use a stream or callback to notify UI
  }

  /// Get time until session timeout
  Duration? getTimeUntilTimeout() {
    if (_lastActivity == null) return null;
    final elapsed = DateTime.now().difference(_lastActivity!);
    final remaining = sessionTimeout - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Dispose resources
  void dispose() {
    _sessionTimer?.cancel();
  }
}
```

#### Step 2: Integrate with App Lifecycle

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_starter/core/security/session_manager.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  SessionManager? _sessionManager;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize session manager
    final container = ProviderScope.containerOf(context);
    _sessionManager = SessionManager(
      secureStorageService: container.read(secureStorageServiceProvider),
      authRepository: container.read(authRepositoryProvider),
    );
    _sessionManager?.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionManager?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // User returned to app, reset session timer
      _sessionManager?.onUserActivity();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // ... existing config ...
    );
  }
}
```

---

## Compliance Features

### 9. GDPR Consent Management

#### Step 1: Create Consent Manager

```dart
// lib/core/privacy/consent_manager.dart
import 'package:flutter_starter/core/storage/secure_storage_service.dart';

/// Manages user consent for GDPR compliance
class ConsentManager {
  ConsentManager(this.secureStorageService);

  final SecureStorageService secureStorageService;

  static const String consentKey = 'user_consent_given';
  static const String consentVersionKey = 'consent_version';
  static const String consentTimestampKey = 'consent_timestamp';
  static const int currentConsentVersion = 1;

  /// Check if user has given consent
  Future<bool> hasUserConsented() async {
    final consented = await secureStorageService.getBool(consentKey);
    final version = await secureStorageService.getInt(consentVersionKey);
    
    return consented == true && version == currentConsentVersion;
  }

  /// Record user consent
  Future<void> recordConsent({
    required bool accepted,
    required Map<String, bool> consentDetails,
  }) async {
    await secureStorageService.setBool(consentKey, value: accepted);
    await secureStorageService.setInt(consentVersionKey, currentConsentVersion);
    await secureStorageService.setInt(
      consentTimestampKey,
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    // Store consent details
    for (final entry in consentDetails.entries) {
      await secureStorageService.setBool(
        'consent_${entry.key}',
        value: entry.value,
      );
    }

    // Apply consent preferences
    if (accepted) {
      await _applyConsentPreferences(consentDetails);
    } else {
      await _revokeConsent();
    }
  }

  /// Apply consent preferences
  Future<void> _applyConsentPreferences(Map<String, bool> preferences) async {
    // Enable/disable analytics based on consent
    final analyticsConsent = preferences['analytics'] ?? false;
    // Configure analytics service
    
    // Enable/disable crash reporting
    final crashReportingConsent = preferences['crash_reporting'] ?? false;
    // Configure crash reporting service
    
    // Enable/disable marketing
    final marketingConsent = preferences['marketing'] ?? false;
    // Configure marketing services
  }

  /// Revoke all consent
  Future<void> _revokeConsent() async {
    // Disable all tracking
    // Clear analytics data
    // Disable marketing
  }

  /// Get consent timestamp
  Future<DateTime?> getConsentTimestamp() async {
    final timestamp = await secureStorageService.getInt(consentTimestampKey);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  }

  /// Check if consent needs renewal (e.g., after 1 year)
  Future<bool> needsConsentRenewal() async {
    final timestamp = await getConsentTimestamp();
    if (timestamp == null) return true;
    
    final oneYearAgo = DateTime.now().subtract(Duration(days: 365));
    return timestamp.isBefore(oneYearAgo);
  }
}
```

#### Step 2: Create Consent Screen

```dart
// lib/features/privacy/presentation/screens/consent_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_starter/core/privacy/consent_manager.dart';

class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _analyticsConsent = false;
  bool _crashReportingConsent = false;
  bool _marketingConsent = false;

  Future<void> _handleConsent(bool accepted) async {
    final consentManager = ref.read(consentManagerProvider);
    
    await consentManager.recordConsent(
      accepted: accepted,
      consentDetails: {
        'analytics': _analyticsConsent,
        'crash_reporting': _crashReportingConsent,
        'marketing': _marketingConsent,
      },
    );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Consent')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'We value your privacy',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Please review and accept our privacy policy and terms of service.',
            ),
            const SizedBox(height: 24),
            CheckboxListTile(
              title: const Text('Analytics'),
              subtitle: const Text('Help us improve the app'),
              value: _analyticsConsent,
              onChanged: (value) => setState(() => _analyticsConsent = value!),
            ),
            CheckboxListTile(
              title: const Text('Crash Reporting'),
              subtitle: const Text('Help us fix bugs'),
              value: _crashReportingConsent,
              onChanged: (value) => setState(() => _crashReportingConsent = value!),
            ),
            CheckboxListTile(
              title: const Text('Marketing'),
              subtitle: const Text('Receive promotional content'),
              value: _marketingConsent,
              onChanged: (value) => setState(() => _marketingConsent = value!),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => _handleConsent(true),
              child: const Text('Accept All'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _handleConsent(false),
              child: const Text('Reject All'),
            ),
          ],
        ),
      ),
    );
  }
}
```

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

