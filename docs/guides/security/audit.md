# Security Audit Report & Hardening Recommendations

This security audit evaluates the Flutter production app across five critical security domains and provides recommendations for hardening.

## Executive Summary

**Overall Security Posture:** Moderate - good foundation, with several
improvements still needed before production.

Read this as a checklist of what to configure, not a list of what is
missing from the code. Several controls below are already implemented and
only need your values (SSL pinning is the main one); each entry states its
status explicitly.

This audit covers:
1. Authentication & Authorization
2. Data Protection
3. Code Security
4. Platform Security
5. Compliance (GDPR/Privacy)

## 1. Authentication & Authorization

### Current Strengths

1. **Secure Token Storage**
   - Using `flutter_secure_storage` with proper platform-specific encryption
   - Android: the plugin's default cipher storage - values encrypted with
     AES-GCM, the key wrapped with RSA-OAEP by a key in the Android Keystore.
     `SecureStorageService` passes no `AndroidOptions`, so `resetOnError` is
     `true`: on an unrecoverable key error the plugin wipes every stored value
     and the user is logged out
   - iOS: Keychain with `first_unlock_this_device` accessibility
   - Tokens stored separately from user data

2. **Token Refresh Mechanism**
   - Automatic token refresh on 401 errors
   - Request queuing during refresh to prevent race conditions
   - Retry logic with prevention of infinite loops
   - Proper exclusion of auth endpoints from refresh logic

3. **Session Management**
   - Token-based authentication with Bearer tokens
   - Refresh token support
   - Automatic logout on refresh failure

### Issues & Recommendations

#### MEDIUM: Bearer tokens in logs

`ApiLoggingInterceptor` redacts the `Authorization` header and every key in its
fixed sensitive set, but a token under a key name outside that set is still
logged. Covered once, under
[Log sanitization covers a fixed key and header set](#medium-log-sanitization-covers-a-fixed-key-and-header-set).

#### MEDIUM: Token Expiration Handling

**Issue:** No explicit token expiration checking before making requests.

**Recommendation:** Implement proactive token expiration checking. See implementation guide for details.

#### MEDIUM: Session Timeout

**Issue:** No automatic session timeout after inactivity.

**Recommendation:** Implement session timeout mechanism. See [Security Implementation Guide](./implementation.md#8-session-management-blueprint).

## 2. Data Protection

### Current Strengths

1. **Secure Storage Implementation**
   - Proper separation of sensitive vs non-sensitive data
   - Platform-specific encryption enabled
   - User data stored in regular storage (non-sensitive)

2. **Network Layer**
   - HTTPS support (baseUrl uses https in production)
   - Proper timeout configurations
   - Error handling and exception mapping

### Issues & Recommendations

#### HIGH: SSL pinning is implemented but inert until you supply fingerprints

**Status:** Implemented. Do **not** add a second pinning library.

`ApiClient` installs an `IOHttpClientAdapter` whose `badCertificateCallback`
SHA-256s the presented certificate's DER bytes and compares it against the
configured pin set (`SslPinning.createAdapter()` in
`lib/core/network/ssl_pinning.dart`). The
`HttpClient` is built with an empty `SecurityContext()`, so every connection is
routed through that callback rather than the platform trust store.
`RawWebSocketClientImpl` opens its `wss://` handshake through the same pinned
`HttpClient` (`SslPinning.createHttpClient()`). Settings
come from `AppConfig.enableSslPinning` and `AppConfig.apiSslFingerprints`
(`lib/core/config/app_config.dart`), which read `ENABLE_SSL_PINNING`
and `API_SSL_FINGERPRINTS` from the environment (both are in `.env.example`).

<!-- symbol: lib/core/network/ssl_pinning.dart SslPinning -->

**What you still have to do:** supply your server's fingerprints. Pinning is
enabled by default in staging and production, but it also needs a non-empty
fingerprint list. With `API_SSL_FINGERPRINTS` unset, which is how
`.env.example` ships, the adapter is never installed and traffic is **not**
pinned. That case is logged as `SSL PINNING MISCONFIGURED` and asserts in debug
builds. The silent fail-open is fixed, but a release
build still runs unpinned.

**Risk while unconfigured:** attackers could intercept and modify network
traffic using a certificate the platform trust store accepts.

**Recommendation:** Extract your fingerprints and set both variables. See
[Security Implementation Guide](./implementation.md#1-ssl-certificate-pinning).

#### MEDIUM: Log sanitization covers a fixed key and header set

**Status:** Implemented.

`ApiLoggingInterceptor` redacts a fixed header set and recursively redacts
sensitive keys via `_sanitizeHeaders`, `_sanitizeBody` and `_sanitizeMap`,
matched against `_sensitiveHeaderKeys`, `_sensitiveKeyFragments` and
`_sensitiveKeysExact`
(`lib/core/network/interceptors/api_logging_interceptor.dart`). It is a no-op
entirely when `AppConfig.enableHttpLogging` is false.

The known sanitizer gaps are closed:
string bodies go through `_sanitizeStringBody`, query parameters through
`_sanitizeMap`, and `proxy-authorization` is in the header set.

**Recommendation:** Extend the key and header lists to cover your own payload
shapes. Redaction matches key names, so a token under an unexpected key is
still logged. See
[Security Implementation Guide](./implementation.md#3-log-sanitization).

#### LOW: Android backup is left on by default

**Status:** Open - an adopter decision. `android/app/src/main/AndroidManifest.xml`
sets no `allowBackup`, `fullBackupContent` or `dataExtractionRules`, so Android's
defaults apply: shared preferences go to cloud backup and to a device-to-device
transfer. The tokens there are Keystore-wrapped ciphertext that cannot be
decrypted on another device - `flutter_secure_storage` fails with
`InvalidKeyException: Failed to unwrap key`, wipes it, and the user signs in
again - but the plaintext preferences (the cached user, the unauthenticated
HTTP cache) move as they are.

**Recommendation:** exclude them from both cloud backup and D2D transfer, with
`dataExtractionRules` for Android 12+ and `fullBackupContent` for earlier
versions. See [Security Implementation Guide](./implementation.md#step-3-create-backup-rules).

#### MEDIUM: On web, tokens sit in localStorage beside their key

**Status:** Open - an adopter decision for any app that ships the web target.

`SecureStorageService` passes no web options, so on Flutter web
`flutter_secure_storage_web` stores the tokens in `window.localStorage`,
AES-GCM encrypted, with the raw AES key stored right beside them. Any script
running on the origin reads and decrypts both the access and the refresh
token. Native platforms are unaffected (Keystore, Keychain).

**Recommendation:** for a web deployment, send a strict Content-Security-Policy
response header, keep access tokens short-lived, and keep the refresh token in
an `httpOnly`, `Secure`, `SameSite` cookie set by the server rather than in
client storage. See [Storage - Web](../../api/core/storage.md#platform-specific-behavior).

## 3. Code Security

### Current Strengths

1. **Environment Configuration**
   - Proper environment variable management
   - Fallback chain: .env → --dart-define → defaults
   - .env files properly gitignored

2. **Debug Checks**
   - `kDebugMode` checks in logging
   - Environment-aware feature flags

### Issues & Recommendations

#### CRITICAL: No Code Obfuscation

**Issue:** No obfuscation configured for release builds. Code is easily reverse-engineered.

**Risk:** Attackers can extract API endpoints, understand business logic, find security vulnerabilities, and extract hardcoded secrets.

**Recommendation:** Enable code obfuscation. See [Security Implementation Guide](./implementation.md#2-code-obfuscation).

#### LOW: Release signing is enforced, but the keystore is yours to supply

**Status:** Implemented.

`android/app/build.gradle.kts` signs `release` only with the keystore named in
`android/key.properties` and never falls back to the debug key. Without that
file every release build is refused ("Release signing is not configured ...
Refusing."); a missing key or a `storeFile` that points at nothing fails the
build too. An unsigned release needs an explicit `-PallowUnsignedRelease=true`
and cannot be installed or uploaded.

**Recommendation:** Create the upload keystore and `android/key.properties`,
keep both out of version control, and back the keystore up. See
[Android deployment - Release signing](../../deployment/android-deployment.md#release-signing).

#### MEDIUM: Root/jailbreak detection is wired but inert

**Status:** Plumbing present, no-op by default.

`freerasp` is in `pubspec.yaml` and `raspServiceProvider`
(`lib/core/security/rasp_providers.dart`) resolves to `NoOpRaspService`, so
**nothing is detected** until you override the provider with a real
implementation. There is also no way to verify this in CI or in a host-VM
test - it only means anything on a physical device.

**Recommendation:** Override the provider. See
[Security Implementation Guide](./implementation.md#7-rootjailbreak-detection-freerasp).

## 4. Platform Security

### Android Security

#### Issues & Recommendations

#### CRITICAL: Missing Security Headers in AndroidManifest

**Issue:** No security-related manifest configurations.

**Recommendation:** Add security configurations. See [Security Implementation Guide](./implementation.md#6-network-security-config).

### iOS Security

#### Issues & Recommendations

#### MEDIUM: Missing Security Headers in Info.plist

**Issue:** No App Transport Security (ATS) configuration visible.

**Recommendation:** Configure ATS explicitly. See implementation guide for details.

### Web Security

#### CRITICAL: Missing Security Headers

**Issue:** `web/index.html` sets no Content-Security-Policy, and no host
configuration ships the response headers.

**Risk:** Vulnerable to XSS, clickjacking, and other web attacks.

**Recommendation:** Add a CSP that still lets Flutter load CanvasKit and its
fallback fonts, and set `X-Frame-Options`, `X-Content-Type-Options` and
`Permissions-Policy` as **response headers** on your host - in a `<meta>` tag
browsers ignore them. See [Security Implementation Guide](./implementation.md#5-security-headers).

## 5. Compliance (GDPR & Privacy)

### Issues & Recommendations

#### MEDIUM: No Privacy Policy Implementation

**Issue:** No visible privacy policy or consent management.

**Recommendation:** Implement GDPR-compliant consent management. See [Security Implementation Guide](./implementation.md#9-gdpr-consent-blueprint).

#### MEDIUM: No Data Deletion Mechanism

**Issue:** No user data deletion functionality visible.

**Recommendation:** Implement "Right to be Forgotten" functionality.

#### MEDIUM: No Data Export Functionality

**Issue:** No mechanism for users to export their data (GDPR requirement).

**Recommendation:** Implement data export functionality.

## Security Checklist

See [Security Checklist](./checklist.md) for a comprehensive checklist of all security tasks.

## Implementation Priority Guide

### Phase 1: Critical Security (Week 1)
1. SSL pinning fingerprints (the code is shipped; supply `API_SSL_FINGERPRINTS`)
2. Code Obfuscation
3. Release signing keystore (the refusal ships; supply your key)
4. Log sanitization coverage for your own header names and payload keys
5. Security Headers

### Phase 2: High Priority (Week 2-3)
1. Network Security Config
2. Root/Jailbreak Detection
3. Session Management
4. R8 keep rules, only if a release build breaks (R8 already runs)

### Phase 3: Compliance (Week 4)
1. GDPR Consent Management
2. Data Deletion
3. Data Export
4. Privacy Policy Integration

## Testing Recommendations

### Security Testing Checklist

- [ ] **Penetration Testing:** Hire professional security firm
- [ ] **Static Analysis:** Use tools like `dart analyze` with security rules
- [ ] **Dynamic Analysis:** Test on rooted/jailbroken devices
- [ ] **Network Testing:** Verify SSL pinning with proxy tools (Burp Suite, OWASP ZAP)
- [ ] **Code Review:** Security-focused code review
- [ ] **Dependency Scanning:** Check for vulnerable dependencies

### Security Testing Tools

1. **OWASP Mobile Security Testing Guide (MSTG)**
2. **MobSF (Mobile Security Framework)**
3. **Burp Suite** for network testing
4. **Frida** for dynamic analysis
5. **APKTool** for Android reverse engineering testing

## Additional Resources

### Security Best Practices
- [OWASP Mobile Top 10](https://owasp.org/www-project-mobile-top-10/)
- [Flutter Security Best Practices](https://docs.flutter.dev/security)
- [Android Security Guidelines](https://developer.android.com/topic/security/best-practices)
- [iOS Security Guidelines](https://developer.apple.com/security/)

### Tools & Libraries
- `flutter_secure_storage` - already in use
- SSL pinning - already implemented natively with `crypto` + `IOHttpClientAdapter`; no extra package needed
- `local_auth` - Biometric authentication
- `root_jailbreak` - Device security checks
- `encrypt` - Additional encryption

### Compliance Resources
- [GDPR Compliance Guide](https://gdpr.eu/)
- [OWASP Privacy Risks](https://owasp.org/www-project-privacy-risks/)

## Conclusion

Your Flutter app has a **solid security foundation** with secure storage, proper token management, and good architecture. However, several **critical improvements** are needed before production deployment:

1. **SSL pinning configuration** - the pinning code ships and is enabled by
   default outside development, but it is inert until you set
   `API_SSL_FINGERPRINTS`
2. **Code Obfuscation** - Critical for protecting intellectual property
3. **Release signing keystore** - the build refuses a release until you supply it
4. **Log sanitization gaps** - the interceptor redacts, but not everywhere
5. **Security Headers** - Essential for web security

**Estimated Implementation Time:** 2-3 weeks for critical items, 1-2 months for comprehensive security hardening.

## Related Documentation

- [Security Implementation Guide](./implementation.md) - Step-by-step implementation instructions
- [Security Checklist](./checklist.md) - Quick reference checklist


