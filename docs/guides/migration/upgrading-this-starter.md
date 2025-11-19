# Upgrading This Starter

This guide helps you upgrade your Flutter starter project to newer versions, handle breaking changes, and use migration scripts.

## Overview

This starter follows [Semantic Versioning](https://semver.org/):
- **MAJOR** version: Breaking changes
- **MINOR** version: New features (backward compatible)
- **PATCH** version: Bug fixes (backward compatible)

## Version Upgrade Process

### Step 1: Check Current Version

```bash
# Check pubspec.yaml
cat pubspec.yaml | grep version

# Check CHANGELOG.md for latest changes
cat CHANGELOG.md
```

### Step 2: Review Breaking Changes

Before upgrading, always check:
1. **CHANGELOG.md** - Lists all changes, including breaking changes
2. **Migration Guides** - This document and version-specific guides
3. **Dependencies** - Check for dependency updates

### Step 3: Backup Your Project

```bash
# Create a backup branch
git checkout -b backup-before-upgrade
git add .
git commit -m "Backup before upgrading to vX.Y.Z"
git checkout main

# Or create a full backup
cp -r . ../flutter_starter_backup
```

### Step 4: Update Dependencies

```bash
# Update Flutter SDK
flutter upgrade

# Update dependencies
flutter pub upgrade

# Or update to specific version
flutter pub upgrade flutter_riverpod:^3.0.3
```

### Step 5: Run Migration Scripts (if available)

```bash
# Check for migration scripts
ls scripts/migration/

# Run migration script for specific version
dart scripts/migration/migrate_to_v2.0.0.dart
```

### Step 6: Fix Breaking Changes

Follow the breaking changes section below for your target version.

### Step 7: Test Your Application

```bash
# Run tests
flutter test

# Run on device
flutter run

# Check for linter errors
flutter analyze
```

## Breaking Changes by Version

### Version 2.0.0 (Hypothetical Future Version)

#### Riverpod 3.0 Migration

**Breaking Change:** Riverpod updated from 2.x to 3.0

**Before:**
```dart
final counterProvider = StateNotifierProvider<CounterNotifier, int>(
  (ref) => CounterNotifier(),
);
```

**After:**
```dart
final counterProvider = NotifierProvider<CounterNotifier, int>(
  CounterNotifier.new,
);
```

**Migration Steps:**
1. Replace `StateNotifierProvider` with `NotifierProvider`
2. Replace `StateNotifier` with `Notifier`
3. Update `build()` method signature
4. Replace `ref.read(provider.notifier)` with `ref.read(provider.notifier)`

**Script:**
```bash
dart scripts/migration/migrate_riverpod_3.0.dart
```

#### Result Pattern Update

**Breaking Change:** `Result<T>` pattern updated

**Before:**
```dart
result.when(
  success: (data) => ...,
  failure: (failure) => ...,
);
```

**After:**
```dart
result.when(
  success: (data) => ...,
  failureCallback: (failure) => ...,
);
```

**Migration Steps:**
1. Find all `result.when(` occurrences
2. Replace `failure:` with `failureCallback:`

**Script:**
```bash
dart scripts/migration/migrate_result_pattern.dart
```

### Version 1.1.0 (Hypothetical Future Version)

#### Configuration System Update

**Breaking Change:** `AppConfig` API updated

**Before:**
```dart
final baseUrl = AppConfig.get('BASE_URL');
```

**After:**
```dart
final baseUrl = AppConfig.baseUrl;
```

**Migration Steps:**
1. Replace `AppConfig.get('KEY')` with typed getters
2. Update all configuration access points

## Migration Scripts

### Creating Migration Scripts

Migration scripts are located in `scripts/migration/`. They help automate common migration tasks.

**Example Script Structure:**
```dart
// scripts/migration/migrate_to_v2.0.0.dart
import 'dart:io';

void main() {
  print('Migrating to v2.0.0...');
  
  // 1. Update dependencies
  _updateDependencies();
  
  // 2. Update code patterns
  _updateCodePatterns();
  
  // 3. Update configuration
  _updateConfiguration();
  
  print('Migration complete!');
}

void _updateDependencies() {
  // Update pubspec.yaml
  final pubspec = File('pubspec.yaml');
  // ... update logic
}

void _updateCodePatterns() {
  // Find and replace code patterns
  // ... update logic
}
```

### Running Migration Scripts

```bash
# Make script executable
chmod +x scripts/migration/migrate_to_v2.0.0.dart

# Run script
dart scripts/migration/migrate_to_v2.0.0.dart

# Or with Flutter
flutter pub run scripts/migration/migrate_to_v2.0.0.dart
```

## Common Upgrade Scenarios

### Scenario 1: Minor Version Update (e.g., 1.0.0 → 1.1.0)

**Steps:**
1. Update dependencies: `flutter pub upgrade`
2. Review CHANGELOG.md for new features
3. Test your application
4. No breaking changes expected

### Scenario 2: Major Version Update (e.g., 1.0.0 → 2.0.0)

**Steps:**
1. Backup your project
2. Review breaking changes in CHANGELOG.md
3. Update dependencies: `flutter pub upgrade`
4. Run migration scripts (if available)
5. Fix breaking changes manually
6. Update your code to use new APIs
7. Run tests: `flutter test`
8. Test on device: `flutter run`
9. Fix any issues

### Scenario 3: Flutter SDK Update

**Steps:**
1. Update Flutter: `flutter upgrade`
2. Check for breaking changes in Flutter release notes
3. Update dependencies: `flutter pub upgrade`
4. Fix any Flutter SDK breaking changes
5. Test your application

### Scenario 4: Dependency Update

**Steps:**
1. Check dependency changelog
2. Update in `pubspec.yaml`
3. Run: `flutter pub get`
4. Check for breaking changes
5. Update code if needed
6. Test your application

## Automated Upgrade Checklist

Use this checklist for each upgrade:

- [ ] **Backup Project**
  - [ ] Create backup branch
  - [ ] Commit current state

- [ ] **Review Changes**
  - [ ] Read CHANGELOG.md
  - [ ] Review breaking changes
  - [ ] Check dependency updates

- [ ] **Update Dependencies**
  - [ ] Update Flutter SDK (if needed)
  - [ ] Update dependencies: `flutter pub upgrade`
  - [ ] Check for conflicts

- [ ] **Run Migration Scripts**
  - [ ] Check for available scripts
  - [ ] Run migration scripts
  - [ ] Verify script results

- [ ] **Fix Breaking Changes**
  - [ ] Update deprecated APIs
  - [ ] Fix compilation errors
  - [ ] Update tests

- [ ] **Test Application**
  - [ ] Run linter: `flutter analyze`
  - [ ] Run tests: `flutter test`
  - [ ] Test on device: `flutter run`
  - [ ] Test on multiple platforms

- [ ] **Update Documentation**
  - [ ] Update your project's README
  - [ ] Update code comments
  - [ ] Document any custom changes

## Version-Specific Guides

### Upgrading to v2.0.0

See [Migration Guide: v1.0.0 to v2.0.0](v1-to-v2-migration.md) (if available)

### Upgrading to v1.1.0

See [Migration Guide: v1.0.0 to v1.1.0](v1.0-to-v1.1-migration.md) (if available)

## Troubleshooting Upgrades

### Issue: Dependency Conflicts

**Solution:**
```bash
# Check dependency tree
flutter pub deps

# Resolve conflicts manually in pubspec.yaml
# Use dependency_overrides if necessary
```

### Issue: Compilation Errors

**Solution:**
1. Check error messages
2. Review breaking changes
3. Update code to use new APIs
4. Check migration guides

### Issue: Tests Failing

**Solution:**
1. Update test mocks
2. Update test expectations
3. Check for API changes
4. Review test documentation

### Issue: Runtime Errors

**Solution:**
1. Check logs for errors
2. Review breaking changes
3. Update error handling
4. Test on clean project

## Best Practices

### 1. Stay Up-to-Date

- Regularly check for updates
- Review CHANGELOG.md
- Test updates in a separate branch

### 2. Incremental Upgrades

- Don't skip major versions
- Upgrade one version at a time
- Test after each upgrade

### 3. Use Version Control

- Commit before upgrading
- Create backup branches
- Tag stable versions

### 4. Document Custom Changes

- Keep track of custom modifications
- Document why changes were made
- Consider contributing back

### 5. Test Thoroughly

- Run all tests
- Test on multiple platforms
- Test critical user flows

## Getting Help

If you encounter issues during upgrade:

1. **Check Documentation**
   - Review this guide
   - Check CHANGELOG.md
   - Review migration guides

2. **Search Issues**
   - Check GitHub issues
   - Search for similar problems

3. **Ask for Help**
   - Create a GitHub issue
   - Provide error messages
   - Include version information

## Related Documentation

- [CHANGELOG.md](../../../CHANGELOG.md) - Complete change history
- [Getting Started](../onboarding/getting-started.md) - Initial setup
- [Understanding the Codebase](../onboarding/understanding-codebase.md) - Architecture overview
- [Common Tasks](../features/common-tasks.md) - Common development tasks

