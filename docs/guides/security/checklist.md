# Security Checklist

Quick reference checklist for security hardening. Check off items as you complete them.

Items marked **(shipped)** are already implemented in this starter; the box is
for confirming you have configured them for your deployment, not for writing
them.

---

## Critical (Must Fix Before Production)

### Authentication & Authorization
- [ ] Confirm the logging interceptor redaction **(shipped, partial)** covers
      your header names and payload shapes - see
      [#78](https://github.com/koniz-dev/flutter-starter/issues/78)
- [ ] Implement token expiration checking
- [ ] Add session timeout mechanism
- [ ] Test token refresh flow thoroughly

### Data Protection
- [ ] **Configure SSL certificate pinning (shipped)** - set
      `API_SSL_FINGERPRINTS` and `ENABLE_SSL_PINNING` in your environment.
      The adapter is implemented at `lib/core/network/api_client.dart:75-101`;
      with no fingerprints it silently does nothing
      ([#84](https://github.com/koniz-dev/flutter-starter/issues/84))
- [ ] Close the remaining log-sanitization gaps (string bodies, query parameters)
- [ ] Encrypt sensitive data at rest (if required)
- [ ] Remove sensitive data from crash reports

### Code Security
- [ ] **Confirm no env file is bundled as an asset (shipped)** - run
      `dart run tool/check_env_assets.dart` **on the tree you are about to
      build**, every release. Flutter asset lists are not build-mode scoped, so
      a `.env` in `pubspec.yaml` ships in the release APK, the release IPA and
      the web build - and so does anything sitting inside a declared directory
      such as `assets/config/`, with no pubspec entry naming it. The check reads
      the tree as it is when it runs, and nothing runs it on the release-build
      path yet ([#135](https://github.com/koniz-dev/flutter-starter/issues/135)).
      Use `--dart-define-from-file=.env` on native; on web, keep secrets on the
      server. See
      [Never ship a secret in the bundle](../configuration.md#never-ship-a-secret-in-the-bundle)
- [ ] **Enable code obfuscation for release builds**
- [ ] **Configure proper Android release signing** (remove debug signing)
- [ ] Add production build guards (prevent debug code in production)
- [ ] Review and remove any hardcoded secrets/API keys
- [ ] Add ProGuard rules for Android

### Platform Security
- [ ] **Add network security config for Android**
- [ ] **Configure App Transport Security for iOS**
- [ ] **Add security headers to web version**
- [ ] Disable backup for Android (or configure backup rules)
- [ ] Configure proper AndroidManifest.xml security settings

---

## High Priority (Fix Within 1-2 Sprints)

### Authentication & Authorization
- [ ] Add biometric authentication option
- [ ] Implement device fingerprinting for fraud detection
- [ ] Add rate limiting for authentication endpoints

### Data Protection
- [ ] Implement request/response encryption for sensitive endpoints
- [ ] Add clipboard protection (auto-clear sensitive data)
- [ ] Implement secure file storage for sensitive documents

### Code Security
- [ ] **Add root/jailbreak detection**
- [ ] Implement anti-tampering checks
- [ ] Add debugger detection
- [ ] Set up dependency vulnerability scanning

### Platform Security
- [ ] Configure Android App Links
- [ ] Configure iOS Associated Domains
- [ ] Add screenshot prevention for sensitive screens
- [ ] Implement secure deep linking

---

## Medium Priority (Fix Within 1 Month)

### Compliance
- [ ] **Implement GDPR consent management**
- [ ] **Add data deletion functionality** (Right to be Forgotten)
- [ ] **Add data export functionality** (GDPR requirement)
- [ ] Create privacy policy screen
- [ ] Add cookie consent for web version

### Monitoring
- [ ] Set up security event logging
- [ ] Implement security monitoring/alerting
- [ ] Add suspicious activity detection
- [ ] Set up crash reporting (sanitized)

### Testing
- [ ] Perform penetration testing
- [ ] Test on rooted/jailbroken devices
- [ ] Test SSL pinning with proxy tools
- [ ] Security-focused code review
- [ ] Dependency vulnerability scan

---

## Pre-Production Checklist

### Build Configuration
- [ ] Release builds use obfuscation
- [ ] Release builds properly signed
- [ ] Debug info files stored securely
- [ ] Environment variables properly configured
- [ ] No debug code in production builds

### Network Security
- [ ] SSL pinning fingerprints set and verified against a proxy
- [ ] Network security config in place
- [ ] No cleartext traffic in production
- [ ] Certificate fingerprints stored securely

### Data Security
- [ ] All sensitive data in secure storage
- [ ] Logs sanitized (no tokens, passwords, etc.)
- [ ] Crash reports sanitized
- [ ] Backup rules configured

### Platform Security
- [ ] Android security configs in place
- [ ] iOS security configs in place
- [ ] Web security headers configured
- [ ] Root/jailbreak detection active

### Compliance
- [ ] GDPR consent flow implemented
- [ ] Privacy policy accessible
- [ ] Data deletion available
- [ ] Data export available

### Testing
- [ ] Security testing completed
- [ ] Penetration testing done
- [ ] All security tests passing
- [ ] Documentation updated

---

## Ongoing Security Tasks

### Weekly
- [ ] Review security logs
- [ ] Check for dependency updates
- [ ] Review error reports for security issues

### Monthly
- [ ] Dependency vulnerability scan
- [ ] Review access logs
- [ ] Update security documentation
- [ ] Review and rotate API keys (if applicable)

### Quarterly
- [ ] Full security audit
- [ ] Penetration testing
- [ ] Review and update security policies
- [ ] Team security training

### Annually
- [ ] Comprehensive security review
- [ ] Third-party security audit
- [ ] Update security certifications
- [ ] Review compliance requirements

---

## Incident Response Checklist

If a security incident occurs:

- [ ] **Immediately:** Revoke all affected tokens
- [ ] **Immediately:** Notify security team
- [ ] **Within 1 hour:** Assess scope of breach
- [ ] **Within 4 hours:** Contain the threat
- [ ] **Within 24 hours:** Notify affected users (if required)
- [ ] **Within 48 hours:** Notify regulatory bodies (if required)
- [ ] **Within 1 week:** Complete investigation
- [ ] **Within 2 weeks:** Implement fixes
- [ ] **Within 1 month:** Post-incident review

---

## Security Resources

### Documentation
- [ ] Security audit report reviewed
- [ ] Implementation guide reviewed
- [ ] Team trained on security practices
- [ ] Incident response plan documented

### Tools Setup
- [ ] Security monitoring tools configured
- [ ] Dependency scanning automated
- [ ] Security testing in CI/CD pipeline
- [ ] Log aggregation configured

---

## Sign-Off

Before deploying to production, ensure:

- [ ] All critical items completed
- [ ] Security testing passed
- [ ] Documentation updated
- [ ] Team trained
- [ ] Monitoring in place

**Reviewed by:** _________________ **Date:** _________

**Approved by:** _________________ **Date:** _________

---

**Last Updated:** November 16, 2025  
**Next Review:** Quarterly or after major releases


