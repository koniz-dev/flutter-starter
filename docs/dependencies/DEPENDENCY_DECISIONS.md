# Dependency Management Decisions

This document outlines the dependency management strategy for the Flutter Starter project, including which dependencies are used, which were removed, and when to add them back.

## Current Dependencies

### Production Dependencies

#### Core Framework
- **flutter** - Core Flutter framework (SDK)
- **cupertino_icons** - iOS style icons

#### State Management
- **flutter_riverpod** - Reactive state management framework

#### Network Layer
- **dio** - HTTP client with interceptors support

#### Storage
- **shared_preferences** - Simple key-value storage for non-sensitive data
- **flutter_secure_storage** - Secure key-value storage for sensitive data (tokens, passwords)

#### Configuration
- **flutter_dotenv** - Environment variable loader from .env files

#### Code Generation (Runtime Annotations)
- **freezed_annotation** - Runtime annotations for Freezed immutable classes
- **json_annotation** - Runtime annotations for JSON serialization

#### Utilities
- **equatable** - Value equality comparison for objects
- **intl** - Internationalization and localization support (used in `date_formatter.dart`)

### Development Dependencies

#### Code Generation
- **build_runner** - Build system for generating code from annotations
- **freezed** - Generates immutable classes, unions, and more
- **json_serializable** - Generates JSON serialization/deserialization code

#### Testing
- **flutter_test** - Flutter testing framework and utilities
- **mocktail** - Mocking library for unit tests

#### Linting
- **very_good_analysis** - Comprehensive lint rules for Flutter/Dart

---

## Removed Dependencies

The following dependencies were removed because they are not currently used in the codebase. They can be added back when needed.

### Production Dependencies Removed

#### UI Components
- **cached_network_image** (^3.4.1)
  - **Reason:** Not used for image loading
  - **When to add back:** When implementing image loading with caching
  - **Alternative:** Can use `Image.network` or add when needed

- **flutter_screenutil** (^5.9.3)
  - **Reason:** Not used for responsive design
  - **When to add back:** When implementing responsive screen size adaptation
  - **Alternative:** Can use Flutter's built-in responsive widgets or add when needed

- **shimmer** (^3.0.0)
  - **Reason:** Not used for loading placeholders
  - **When to add back:** When implementing loading placeholder shimmer effects
  - **Alternative:** Can implement custom loading indicators or add when needed

#### Routing
- **go_router** (^17.0.0)
  - **Reason:** Not used for routing (currently using MaterialApp)
  - **When to add back:** When implementing declarative routing with type-safe navigation
  - **Alternative:** Can use Flutter's built-in Navigator or add when implementing routing

#### Storage
- **hive** (^2.2.3)
- **hive_flutter** (^1.1.0)
  - **Reason:** Not used for local database storage
  - **When to add back:** When implementing local NoSQL database storage
  - **Alternative:** Currently using `shared_preferences` and `flutter_secure_storage`

#### Network Layer
- **retrofit** (^4.9.0)
  - **Reason:** Not used for type-safe HTTP client generation
  - **When to add back:** When implementing type-safe HTTP client with code generation
  - **Alternative:** Currently using `dio` directly

#### Utilities
- **logger** (^2.6.2)
  - **Reason:** Not used for logging (only mentioned in comments)
  - **When to add back:** When implementing structured logging
  - **Alternative:** Can use `print` statements or `debugPrint` for now

#### Code Generation (Runtime Annotations)
- **riverpod_annotation** (^3.0.3)
  - **Reason:** Not used (using manual Riverpod providers)
  - **When to add back:** When implementing Riverpod code generation
  - **Alternative:** Currently using manual provider definitions

### Development Dependencies Removed

#### Code Generation
- **go_router_builder** (^4.1.1)
  - **Reason:** Not used (go_router removed)
  - **When to add back:** When implementing go_router routing

- **retrofit_generator** (^10.1.4)
  - **Reason:** Not used (retrofit removed)
  - **When to add back:** When implementing retrofit type-safe HTTP client

- **riverpod_generator** (^3.0.3)
  - **Reason:** Not used (using manual providers)
  - **When to add back:** When implementing Riverpod code generation

---

## Dependency Usage Summary

### Used Dependencies
- ✅ All production dependencies are actively used in the codebase
- ✅ All development dependencies are used for code generation or testing

### Removed Dependencies
- ❌ 9 production dependencies removed (not used)
- ❌ 3 development dependencies removed (not used)

### Impact
- **App Size:** Reduced by removing unused packages
- **Build Time:** Potentially faster (fewer packages to resolve)
- **Complexity:** Reduced dependency tree
- **Security:** Reduced attack surface (fewer dependencies to maintain)

---

## Adding Dependencies Back

When you need to add a removed dependency back:

1. **Add to pubspec.yaml:**
   ```yaml
   dependencies:
     package_name: ^version
   ```

2. **Run:**
   ```bash
   flutter pub get
   ```

3. **Update this document** to reflect the dependency is now used

4. **Remove the comment** from the "REMOVED UNUSED DEPENDENCIES" section in `pubspec.yaml`

---

## Dependency Strategy

### Principles
1. **Only add what you need** - Don't add dependencies "just in case"
2. **Remove unused dependencies** - Regularly audit and remove unused packages
3. **Document decisions** - Keep this document updated with dependency decisions
4. **Consider alternatives** - Evaluate if built-in Flutter/Dart features can be used instead

### When to Add a Dependency
- ✅ The feature is actively being implemented
- ✅ The dependency provides significant value over manual implementation
- ✅ The dependency is well-maintained and secure
- ✅ The dependency doesn't conflict with existing dependencies

### When to Remove a Dependency
- ❌ The dependency is not imported anywhere in the codebase
- ❌ The dependency is not used in tests
- ❌ The dependency is not required by other dependencies
- ❌ The feature it provides is not planned for the near future

---

## Maintenance

This document should be updated when:
- Dependencies are added
- Dependencies are removed
- Dependency usage changes
- New features require new dependencies

**Last Updated:** After GROUP_8 implementation (Dependency Cleanup)

---

## References

- [Flutter Package Management](https://docs.flutter.dev/development/packages-and-plugins/using-packages)
- [pub.dev](https://pub.dev/) - Dart package repository
- [Dependency Best Practices](https://dart.dev/guides/libraries/creating-packages)

