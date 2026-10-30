# Upgrading This Starter

This guide helps you upgrade your Flutter starter project to newer versions and
handle breaking changes.

**Starter version:** 2.0.0

That line records which release of the starter this copy of the template came
from. It is not your app's version (`version:` in `pubspec.yaml` is yours), and
nothing updates it in your project, so it keeps telling you where you started.
Each release is a tag on the upstream repository with notes on
[its releases page](https://github.com/koniz-dev/flutter-starter/releases), listing every change you may have to make.

`scripts/dev/migration/` **does not exist** in this repository - it is the
convention this guide proposes for migration scripts you or a future release
may add. The "Version 2.1.0 (Hypothetical Future Version)" section below is an
illustration of the format, not a record of changes.

## Overview

This starter follows [Semantic Versioning](https://semver.org/):
- **MAJOR** version: Breaking changes
- **MINOR** version: New features (backward compatible)
- **PATCH** version: Bug fixes (backward compatible)

## Version Upgrade Process

### Step 1: Check Current Version

Your starting point is the **Starter version** line at the top of this file,
not `pubspec.yaml`:

```bash
grep -m1 'Starter version' docs/guides/migration/upgrading-this-starter.md
```

Every release is tagged upstream, so you can list and diff what changed since
yours (`v2.0.0` below stands for the version that line shows):

```bash
git remote add upstream https://github.com/koniz-dev/flutter-starter.git
git fetch upstream --tags
git log --oneline v2.0.0..upstream/main      # every upstream commit since
git diff --stat v2.0.0 upstream/main -- lib  # what changed in the code
```

Then read the [release notes](https://github.com/koniz-dev/flutter-starter/releases) from your version onwards. Your own
`CHANGELOG.md` records your project's releases, not the starter's.

### Step 2: Review Breaking Changes

Before upgrading, always check:
1. **[The starter's release notes](https://github.com/koniz-dev/flutter-starter/releases)** - Every release, with what you have to change for each breaking one
2. **Migration Guides** - This document and version-specific guides
3. **Dependencies** - Check for dependency updates

### Step 3: Backup Your Project

```bash
# Create a backup branch. `git add .` is deliberate here - a backup wants
# everything, including generated files. Do not carry the habit into a
# feature branch; see CONTRIBUTING.md.
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

### Step 5: Run Migration Scripts (if any)

No migration scripts ship with this starter today; `scripts/dev/migration/`
does not exist. When a release adds one, its release notes name the script and
you run it from the repository root:

```bash
# Only if the release notes say a script exists
ls scripts/dev/migration/ 2>/dev/null || echo "no migration scripts in this version"
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

### Already current: riverpod_generator 4 and Freezed 4

The starter generates code with `riverpod_generator` 4, `riverpod_annotation`
4 and `freezed` 4. Code carried over from an older copy needs two changes:

- **Generated providers are no longer `const`.** An alias such as
  `const AuthNotifierProvider authNotifierProvider = authProvider;` no longer
  compiles ("Const variables must be initialized with a constant value");
  declare it `final`. Anything that put a generated provider inside a `const`
  list or constructor call needs the same change.
- **Freezed no longer accepts `final` on a constructor parameter.** Dart 3.13
  removed that syntax, so `@unfreezed` can no longer make a single field
  immutable that way.

After pulling the upgrade, regenerate:
`dart run build_runner build --delete-conflicting-outputs`.

### Already current: Riverpod 3 and `failureCallback:`

Both changes below are **already in this starter** - `pubspec.yaml` depends on
`flutter_riverpod` 3.x, and `Result.when` in
`lib/core/utils/result.dart` takes `failureCallback:`. They are kept here for
anyone carrying code from an older copy of the template.

#### Riverpod 3.0 Migration

**Change:** Riverpod 2.x to 3.0

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

**Script:** none ships; the steps above are manual.

#### Result Pattern Update

**Change:** `Result.when`'s failure parameter is `failureCallback:`

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

**Script:** none ships; the steps above are manual.

### Version 2.1.0 (Hypothetical Future Version)

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

There are no migration scripts in this repository yet, and no
`scripts/dev/migration/` directory. The convention below is what to follow if
you add one - create the directory as part of that change.

**Example Script Structure:**
```dart
// scripts/dev/migration/migrate_to_v3.0.0.dart
import 'dart:io';

void main() {
  print('Migrating to v3.0.0...');
  
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
# Make script executable (after you have created it)
chmod +x scripts/dev/migration/migrate_to_v3.0.0.dart

# Run script
dart scripts/dev/migration/migrate_to_v3.0.0.dart

# Or with Flutter
flutter pub run scripts/dev/migration/migrate_to_v3.0.0.dart
```

## Common Upgrade Scenarios

### Scenario 1: Minor Version Update (e.g., 1.0.0 → 1.1.0)

**Steps:**
1. Update dependencies: `flutter pub upgrade`
2. Review the starter's changelog for new features
3. Test your application
4. No breaking changes expected

### Scenario 2: Major Version Update (e.g., 1.0.0 → 2.0.0)

**Steps:**
1. Backup your project
2. Review breaking changes in the starter's changelog
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
  - [ ] Read the starter's changelog
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

No version-specific guides exist yet, because no version after `1.0.0` has been
released. When one is, it will be added to this directory and listed here, and
linked from the starter's changelog.

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
- Review the starter's changelog
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
   - Check the starter's changelog
   - Review migration guides

2. **Search Issues**
   - Check GitHub issues
   - Search for similar problems

3. **Ask for Help**
   - Create a GitHub issue
   - Provide error messages
   - Include version information

## Related Documentation

- [The starter's release notes](https://github.com/koniz-dev/flutter-starter/releases) - Every release, including what each breaking change asks of you
- [Getting Started](../onboarding/getting-started.md) - Initial setup
- [Understanding the Codebase](../onboarding/understanding-codebase.md) - Architecture overview
- [Common Tasks](../features/common-tasks.md) - Common development tasks


