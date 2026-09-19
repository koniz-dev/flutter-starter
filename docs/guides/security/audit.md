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
   - Android: EncryptedSharedPreferences enabled
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

`ApiLoggingInterceptor` redacts the `Authorization` header, but the redaction
is partial for other shapes. Covered once, under
[Log sanitization is partial](#medium-log-sanitization-is-partial).

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
configured pin set (`lib/core/network/api_client.dart:75-101`). The
`HttpClient` is built with an empty `SecurityContext()`, so every connection is
routed through that callback rather than the platform trust store. Settings
come from `AppConfig.enableSslPinning` and `AppConfig.apiSslFingerprints`
(`lib/core/config/app_config.dart:110-141`), which read `ENABLE_SSL_PINNING`
and `API_SSL_FINGERPRINTS` from the environment (`.env.example:34-39`).

**What you still have to do:** supply your server's fingerprints. Pinning is
enabled by default in staging and production, but the guard at
`api_client.dart:76` also requires a non-empty fingerprint list, so with
`API_SSL_FINGERPRINTS` unset - which is how `.env.example` ships - the adapter
is never installed and traffic is **not** pinned. Nothing warns you. That
fail-open behaviour is tracked separately in
[#84](https://github.com/koniz-dev/flutter-starter/issues/84).

**Risk while unconfigured:** attackers could intercept and modify network
traffic using a certificate the platform trust store accepts.

**Recommendation:** Extract your fingerprints and set both variables. See
[Security Implementation Guide](./implementation.md#1-ssl-certificate-pinning).

#### MEDIUM: Log sanitization is partial

**Status:** Implemented with known gaps.

`ApiLoggingInterceptor` redacts a fixed header set and recursively redacts
sensitive JSON keys via `_sanitizeHeaders` / `_sanitizeJson`
(`lib/core/network/interceptors/api_logging_interceptor.dart`). It is a no-op
entirely when `AppConfig.enableHttpLogging` is false.

The gaps that remain are enumerated in
[#78](https://github.com/koniz-dev/flutter-starter/issues/78): string request
bodies bypass `_sanitizeJson`, query parameters are never sanitized, and
`proxy-authorization` is not in the header set.

**Recommendation:** Track #78, and extend the key and header lists to cover
your own payload shapes. See
[Security Implementation Guide](./implementation.md#3-log-sanitization).

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

#### CRITICAL: Debug Signing in Release

**Issue:** Release builds use debug signing keys.

**Location:** `android/app/build.gradle.kts:49`

**Risk:** Anyone can install debug builds, and release builds aren't properly signed.

**Recommendation:** Configure proper release signing. See [Security Implementation Guide](./implementation.md#4-android-release-signing).

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

**Issue:** No security headers in `index.html`.

**Risk:** Vulnerable to XSS, clickjacking, and other web attacks.

**Recommendation:** Add security headers. See [Security Implementation Guide](./implementation.md#5-security-headers).

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
3. Release Signing
4. Log sanitization gaps (see [#78](https://github.com/koniz-dev/flutter-starter/issues/78))
5. Security Headers

### Phase 2: High Priority (Week 2-3)
1. Network Security Config
2. Root/Jailbreak Detection
3. Session Management
4. ProGuard Rules

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
3. **Release Signing** - Required for app store distribution
4. **Log sanitization gaps** - the interceptor redacts, but not everywhere
5. **Security Headers** - Essential for web security

**Estimated Implementation Time:** 2-3 weeks for critical items, 1-2 months for comprehensive security hardening.

## Related Documentation

- [Security Implementation Guide](./implementation.md) - Step-by-step implementation instructions
- [Security Checklist](./checklist.md) - Quick reference checklist


