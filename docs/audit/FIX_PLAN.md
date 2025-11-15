# Flutter Starter Project - Grouped Fix Plan

**Last Updated:** November 15, 2025

**Based on:** Comprehensive Architecture Audit Report  
**Total Issues:** 47  
**Estimated Total Effort:** 45-66 hours

---

## Fix Strategy Overview

Issues are grouped by:
- **Dependencies** - What must be fixed first
- **Logical cohesion** - Related issues that should be fixed together
- **Impact** - Critical issues prioritized
- **Effort** - Balanced workload per group

---

## Group 1: Error Handling Foundation ⚠️ CRITICAL

**Issues:** #1, #5, #20, #21, #24  
**Severity:** Critical  
**Effort:** 12-14 hours  
**Dependencies:** None (start here)  
**Priority:** HIGHEST

### Issues in this group:
- **#1** - DioException Never Converted to Domain Exceptions
- **#5** - Missing Exception-to-Failure Mapping
- **#20** - Missing Error Interceptor for DioException Conversion
- **#21** - Inconsistent Error Handling in Remote Data Source
- **#24** - Missing Result Type for Typed Failures

### Approach:
1. **Create `DioExceptionMapper` utility** (#1, #20)
   - Map `DioException` types to domain exceptions
   - Handle connection errors, timeouts, response errors
   - Extract status codes and error messages

2. **Create `ExceptionToFailureMapper` utility** (#5)
   - Convert domain exceptions to typed failures
   - Map: `ServerException` → `ServerFailure`
   - Map: `NetworkException` → `NetworkFailure`
   - Map: `CacheException` → `CacheFailure`
   - Map: `AuthException` → `AuthFailure`

3. **Create `ErrorInterceptor`** (#20)
   - Add to Dio interceptors chain
   - Convert `DioException` to domain exceptions before reaching data sources
   - Handle error transformation centrally

4. **Update `Result<T>` type** (#24)
   - Change `ResultFailure` to accept `Failure` type parameter
   - Or create `FailureResult<T, F extends Failure>`
   - Update all repository return types

5. **Update `AuthRemoteDataSource`** (#21)
   - Remove status code checks (Dio throws for errors)
   - Remove generic exception wrapping
   - Let error interceptor handle conversion
   - Simplify error handling logic

6. **Update `AuthRepositoryImpl`** (#5)
   - Use `ExceptionToFailureMapper` instead of `ResultFailure`
   - Return typed failures: `ServerFailure`, `NetworkFailure`, `CacheFailure`
   - Update all catch blocks

### Files to create:
- `lib/core/errors/dio_exception_mapper.dart`
- `lib/core/errors/exception_to_failure_mapper.dart`
- `lib/core/network/interceptors/error_interceptor.dart`

### Files to modify:
- `lib/core/utils/result.dart` - Update Result type
- `lib/core/network/api_client.dart` - Add error interceptor
- `lib/features/auth/data/datasources/auth_remote_datasource.dart` - Simplify error handling
- `lib/features/auth/data/repositories/auth_repository_impl.dart` - Use typed failures

### Testing:
- Unit tests for `DioExceptionMapper`
- Unit tests for `ExceptionToFailureMapper`
- Integration test for error flow (network error → exception → failure → UI)
- Test all DioException types (connection, timeout, response, etc.)

### Success Criteria:
- ✅ All DioExceptions converted to domain exceptions
- ✅ All exceptions mapped to typed failures
- ✅ Error interceptor handles conversion automatically
- ✅ Repositories return typed failures
- ✅ UI can distinguish error types

---

## Group 2: Configuration Cleanup ⚠️ CRITICAL

**Issues:** #2, #3, #19, #25, #31, #32  
**Severity:** Critical + Important  
**Effort:** 3-4 hours  
**Dependencies:** None  
**Priority:** HIGH

### Issues in this group:
- **#2** - Duplicate Configuration Sources (BASE_URL Conflict)
- **#3** - Duplicate Timeout Configuration
- **#19** - ApiClient Timeout Configuration Ignored
- **#25** - AppConstants.appVersion Hardcoded
- **#31** - Unused AppConstants Values
- **#32** - ApiEndpoints.baseUrl Unused

### Approach:
1. **Remove duplicate BASE_URL** (#2, #32)
   - Remove `baseUrl` from `ApiEndpoints` class
   - Use only `AppConfig.baseUrl` everywhere
   - Update `ApiClient` to use `AppConfig.baseUrl`

2. **Consolidate timeout configuration** (#3, #19, #31)
   - Remove unused timeout constants from `AppConstants`
   - Use `AppConfig.apiConnectTimeout` and `AppConfig.apiReceiveTimeout` in `ApiClient`
   - Remove hardcoded `Duration(seconds: 30)` values
   - Update `ApiClient._createDio()` to use config values

3. **Fix app version duplication** (#25)
   - Remove `appVersion` from `AppConstants`
   - Use only `AppConfig.appVersion` (reads from environment)
   - Update any references to use `AppConfig`

### Files to modify:
- `lib/core/constants/api_endpoints.dart` - Remove `baseUrl`
- `lib/core/constants/app_constants.dart` - Remove unused timeouts and `appVersion`
- `lib/core/config/app_config.dart` - Verify all config values are used
- `lib/core/network/api_client.dart` - Use config timeouts

### Testing:
- Verify `AppConfig` values are used in `ApiClient`
- Test timeout values from environment variables
- Verify no hardcoded values remain

### Success Criteria:
- ✅ Single source of truth for BASE_URL (`AppConfig`)
- ✅ Single source of truth for timeouts (`AppConfig`)
- ✅ No unused constants
- ✅ `ApiClient` uses config values, not hardcoded

---

## Group 3: Storage & Security ⚠️ CRITICAL

**Issues:** #4, #10, #28  
**Severity:** Critical + Important  
**Effort:** 4-6 hours  
**Dependencies:** None  
**Priority:** HIGH

### Issues in this group:
- **#4** - StorageService Initialized Twice (Duplicate Instances)
- **#10** - flutter_secure_storage Not Used (Security Risk)
- **#28** - Missing Secure Storage for Tokens

### Approach:
1. **Fix StorageService initialization** (#4)
   - Remove manual initialization from `main.dart`
   - Create startup provider to initialize storage
   - Use Riverpod provider exclusively
   - Ensure single instance throughout app

2. **Implement SecureStorageService** (#10, #28)
   - Create `SecureStorageService` wrapper for `flutter_secure_storage`
   - Implement `IStorageService` interface
   - Use for sensitive data (tokens)
   - Keep `SharedPreferences` for non-sensitive data

3. **Update AuthLocalDataSource** (#28)
   - Use `SecureStorageService` for tokens (`tokenKey`, `refreshTokenKey`)
   - Use `SharedPreferences` for user data (`userDataKey`)
   - Update all token storage/retrieval methods

### Files to create:
- `lib/core/storage/secure_storage_service.dart`
- `lib/core/di/startup_providers.dart` (or add to existing providers)

### Files to modify:
- `lib/main.dart` - Remove manual StorageService initialization
- `lib/core/di/providers.dart` - Add startup initialization
- `lib/core/storage/storage_service.dart` - Keep for non-sensitive data
- `lib/features/auth/data/datasources/auth_local_datasource.dart` - Use secure storage for tokens

### Testing:
- Test secure storage for tokens
- Test SharedPreferences for user data
- Verify single StorageService instance
- Test token persistence across app restarts

### Success Criteria:
- ✅ Single StorageService instance via Riverpod
- ✅ Tokens stored in secure storage
- ✅ User data in SharedPreferences
- ✅ No security risks from plain text token storage

---

## Group 4: Token Refresh & Auth Interceptor ⚠️ CRITICAL

**Issues:** #6  
**Severity:** Critical  
**Effort:** 4-6 hours  
**Dependencies:** Group 1 (Error Handling), Group 3 (Storage)  
**Priority:** HIGH

### Issues in this group:
- **#6** - Token Refresh Logic Incomplete

### Approach:
1. **Implement token refresh in AuthInterceptor** (#6)
   - Handle 401 Unauthorized responses
   - Call `refreshToken()` from repository
   - Retry original request with new token
   - Handle refresh failure (logout user, clear cache)

2. **Add retry logic**
   - Store original request
   - Refresh token
   - Retry with new Authorization header
   - Prevent infinite retry loops

3. **Handle refresh failure**
   - If refresh fails, clear auth state
   - Navigate to login screen
   - Show appropriate error message

### Files to modify:
- `lib/core/network/interceptors/auth_interceptor.dart` - Implement refresh logic
- `lib/core/di/providers.dart` - May need to access auth repository/provider

### Testing:
- Test successful token refresh and retry
- Test refresh failure handling
- Test infinite retry prevention
- Test concurrent requests during refresh

### Success Criteria:
- ✅ 401 errors trigger automatic token refresh
- ✅ Original request retried with new token
- ✅ Refresh failure handled gracefully
- ✅ No infinite retry loops

---

## Group 5: Use Cases & Clean Architecture ⚠️ CRITICAL

**Issues:** #8, #22, #23  
**Severity:** Critical + Important  
**Effort:** 6-8 hours  
**Dependencies:** Group 1 (Error Handling)  
**Priority:** HIGH

### Issues in this group:
- **#8** - Missing Use Case Providers
- **#22** - Missing Register, Logout, RefreshToken Use Cases
- **#23** - AuthNotifier Missing Methods

### Approach:
1. **Create missing use cases** (#22)
   - `RegisterUseCase`
   - `LogoutUseCase`
   - `RefreshTokenUseCase`
   - `GetCurrentUserUseCase`
   - `IsAuthenticatedUseCase`

2. **Create use case providers** (#8)
   - Add providers for all use cases in `providers.dart`
   - Follow same pattern as `loginUseCaseProvider`

3. **Update AuthNotifier** (#23)
   - Add `register()` method
   - Add `logout()` method
   - Add `refreshToken()` method
   - Add `getCurrentUser()` method
   - Add `isAuthenticated()` method
   - Use corresponding use cases (not repository directly)

4. **Update state management**
   - Handle loading states for all operations
   - Handle error states properly
   - Clear errors before new operations

### Files to create:
- `lib/features/auth/domain/usecases/register_usecase.dart`
- `lib/features/auth/domain/usecases/logout_usecase.dart`
- `lib/features/auth/domain/usecases/refresh_token_usecase.dart`
- `lib/features/auth/domain/usecases/get_current_user_usecase.dart`
- `lib/features/auth/domain/usecases/is_authenticated_usecase.dart`

### Files to modify:
- `lib/core/di/providers.dart` - Add use case providers
- `lib/features/auth/presentation/providers/auth_provider.dart` - Add all methods

### Testing:
- Unit tests for each use case
- Test AuthNotifier state transitions
- Test error handling in each method

### Success Criteria:
- ✅ All auth operations have use cases
- ✅ All use cases have providers
- ✅ AuthNotifier uses use cases (not repository)
- ✅ All auth operations available in UI layer

---

## Group 6: Result Type & Pattern Matching

**Issues:** #7, #34  
**Severity:** Critical + Minor  
**Effort:** 3-4 hours  
**Dependencies:** Group 1 (Error Handling)  
**Priority:** MEDIUM

### Issues in this group:
- **#7** - Result.when() Method Signature Mismatch
- **#34** - Inconsistent Naming: ResultFailure vs Failure Classes

### Approach:
1. **Update Result.when() method** (#7)
   - Use proper Dart 3.0 pattern matching
   - Or document named parameter approach clearly
   - Consider using `freezed` for union types (if implementing code generation)

2. **Clarify ResultFailure vs Failure naming** (#34)
   - Document relationship between `ResultFailure` and `Failure` classes
   - Update naming if needed
   - Ensure consistent usage

### Files to modify:
- `lib/core/utils/result.dart` - Update `when()` method or documentation
- `lib/core/errors/failures.dart` - Document relationship

### Testing:
- Test `Result.when()` usage
- Verify pattern matching works correctly

### Success Criteria:
- ✅ `Result.when()` uses proper pattern matching or is clearly documented
- ✅ Naming relationship between ResultFailure and Failure is clear
- ✅ Consistent usage throughout codebase

---

## Group 7: Code Generation Implementation

**Issues:** #13, #17, #18  
**Severity:** Important  
**Effort:** 8-12 hours  
**Dependencies:** None (can be done independently)  
**Priority:** MEDIUM

### Issues in this group:
- **#13** - Code Generation Annotations Not Used
- **#17** - Manual JSON Serialization Instead of Generated Code
- **#18** - AuthState Should Use Freezed

### Approach:
1. **Implement @freezed for AuthState** (#18)
   - Add `@freezed` annotation
   - Run `build_runner`
   - Remove manual `copyWith` implementation
   - Update all usages

2. **Implement @JsonSerializable for models** (#17)
   - Add `@JsonSerializable` to `UserModel`
   - Add `@JsonSerializable` to `AuthResponseModel`
   - Run `build_runner`
   - Remove manual `fromJson`/`toJson` methods
   - Update all usages

3. **Consider @freezed for Result type** (#13)
   - If using freezed, convert `Result` to freezed union
   - Better pattern matching support
   - Or keep current sealed class approach

### Files to modify:
- `lib/features/auth/presentation/providers/auth_provider.dart` - Add @freezed
- `lib/features/auth/data/models/user_model.dart` - Add @JsonSerializable
- `lib/features/auth/data/models/auth_response_model.dart` - Add @JsonSerializable
- `lib/core/utils/result.dart` - Consider @freezed (optional)

### Build commands:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Testing:
- Verify generated code works
- Test JSON serialization/deserialization
- Test AuthState copyWith

### Success Criteria:
- ✅ AuthState uses @freezed
- ✅ Models use @JsonSerializable
- ✅ Generated code works correctly
- ✅ Less boilerplate code

---

## Group 8: Unused Dependencies Cleanup

**Issues:** #9, #11, #12, #14, #15, #16, #29, #30, #37, #38, #39, #40, #41  
**Severity:** Important + Minor  
**Effort:** 2-3 hours (to remove) OR 20-30 hours (to implement)  
**Dependencies:** None  
**Priority:** MEDIUM

### Decision Required:
**Option A: Remove unused dependencies** (2-3 hours)
- Clean up `pubspec.yaml`
- Remove unused packages
- Reduce app size and complexity

**Option B: Implement unused dependencies** (20-30 hours)
- Implement all declared features
- Use all dependencies as intended

### Recommended: **Option A** (Remove for now, add back when needed)

### Issues in this group:
- **#9** - Hive Not Used
- **#11** - go_router Not Used
- **#12** - Retrofit Not Used
- **#14** - UI Packages Not Used (cached_network_image, flutter_screenutil, shimmer)
- **#15** - Logger Not Used
- **#16** - Equatable Only Used in Failures
- **#29** - Missing Hive Implementation
- **#30** - Missing Retrofit API Interface
- **#37** - Missing Error Message Localization (intl)
- **#38** - LoggingInterceptor Uses debugPrint
- **#39** - Missing Shimmer Loading Placeholders
- **#40** - Missing Cached Network Image Usage
- **#41** - Missing Flutter ScreenUtil Usage

### Approach (Option A - Remove):
1. **Remove unused packages from pubspec.yaml**
   - `hive`, `hive_flutter`
   - `go_router`, `go_router_builder`
   - `retrofit`, `retrofit_generator`
   - `cached_network_image`
   - `flutter_screenutil`
   - `shimmer`
   - `logger` (or implement it - see #38)
   - `intl` (if not planning localization)

2. **Keep but document:**
   - `equatable` - Used in failures, consider for entities
   - `freezed_annotation`, `json_annotation` - If implementing Group 7
   - `riverpod_annotation` - Optional, can keep manual providers

3. **Update documentation**
   - Document removed dependencies
   - Note when to add back if needed

### Files to modify:
- `pubspec.yaml` - Remove unused dependencies
- `README.md` - Document dependency decisions

### Success Criteria:
- ✅ No unused dependencies in pubspec.yaml
- ✅ All declared dependencies are used
- ✅ App size reduced
- ✅ Clear dependency strategy

---

## Group 9: UI/UX Improvements

**Issues:** #26, #27, #42, #43, #44, #45, #46  
**Severity:** Important + Minor  
**Effort:** 6-8 hours  
**Dependencies:** Group 5 (Use Cases)  
**Priority:** LOW-MEDIUM

### Issues in this group:
- **#26** - Missing Validation in Login Screen
- **#27** - ContextExtensions.navigateTo Uses MaterialApp Navigator
- **#42** - AppConfig.enableLogging vs enableHttpLogging
- **#43** - Missing Register Screen
- **#44** - Missing Error Handling in AuthNotifier
- **#45** - Missing Loading State for Other Auth Operations
- **#46** - Missing Validation Error Messages

### Approach:
1. **Improve login screen validation** (#26, #46)
   - Use `Validators.isValidEmail()` for email
   - Use `Validators.isValidPassword()` for password
   - Show specific error messages
   - Improve UX with helpful feedback

2. **Create RegisterScreen** (#43)
   - Similar to LoginScreen
   - Use `RegisterUseCase`
   - Proper validation
   - Error handling

3. **Fix AuthNotifier error handling** (#44)
   - Clear error state before new operations
   - Reset error on success
   - Handle state transitions properly

4. **Add loading states** (#45)
   - Add loading for register, logout, refreshToken
   - Update UI to show loading indicators
   - Handle loading state transitions

5. **Clarify logging flags** (#42)
   - Document `enableLogging` vs `enableHttpLogging`
   - Or consolidate if redundant

6. **Update navigation extensions** (#27)
   - Document current approach
   - Or update to go_router if implementing

### Files to create:
- `lib/features/auth/presentation/screens/register_screen.dart`

### Files to modify:
- `lib/features/auth/presentation/screens/login_screen.dart` - Improve validation
- `lib/features/auth/presentation/providers/auth_provider.dart` - Fix error handling, add loading states
- `lib/core/config/app_config.dart` - Document logging flags
- `lib/shared/extensions/context_extensions.dart` - Document or update navigation

### Testing:
- Test validation in login/register screens
- Test error state handling
- Test loading states

### Success Criteria:
- ✅ Proper validation in login/register screens
- ✅ Register screen implemented
- ✅ Error handling works correctly
- ✅ Loading states for all operations
- ✅ Clear logging flag documentation

---

## Group 10: Documentation & Testing

**Issues:** #33, #35, #47  
**Severity:** Minor  
**Effort:** 8-12 hours  
**Dependencies:** All previous groups  
**Priority:** LOW

### Issues in this group:
- **#33** - Missing Documentation for Exception-to-Failure Mapping Strategy
- **#35** - Missing Dartdoc for Some Public APIs
- **#47** - Missing Test Files

### Approach:
1. **Document exception-to-failure mapping** (#33)
   - Create architecture decision record (ADR)
   - Document mapping strategy
   - Provide usage examples
   - Add to architecture docs

2. **Add dartdoc comments** (#35)
   - Add to all public APIs
   - Include usage examples
   - Document parameters and return values

3. **Add test coverage** (#47)
   - Unit tests for use cases
   - Repository tests with mocks
   - Widget tests for UI
   - Integration tests for auth flow
   - Use `mocktail` for mocking

### Files to create:
- `docs/architecture/error-handling.md`
- `test/features/auth/domain/usecases/login_usecase_test.dart`
- `test/features/auth/data/repositories/auth_repository_impl_test.dart`
- `test/features/auth/presentation/screens/login_screen_test.dart`
- (More test files as needed)

### Files to modify:
- All public APIs - Add dartdoc comments
- `ARCHITECTURE.md` - Add error handling section

### Testing:
- Achieve 70%+ code coverage
- Test all error paths
- Test happy paths
- Test edge cases

### Success Criteria:
- ✅ Error handling strategy documented
- ✅ All public APIs have dartdoc
- ✅ Test coverage > 70%
- ✅ All critical paths tested

---

## Implementation Timeline

### Week 1: Critical Foundations
- **Day 1-2:** Group 1 (Error Handling Foundation) - 12-14 hours
- **Day 3:** Group 2 (Configuration Cleanup) - 3-4 hours
- **Day 4:** Group 3 (Storage & Security) - 4-6 hours
- **Day 5:** Group 4 (Token Refresh) - 4-6 hours

**Week 1 Total:** ~23-30 hours

### Week 2: Feature Completion
- **Day 1-2:** Group 5 (Use Cases) - 6-8 hours
- **Day 3:** Group 6 (Result Type) - 3-4 hours
- **Day 4:** Group 8 (Dependency Cleanup) - 2-3 hours
- **Day 5:** Group 9 (UI/UX) - 6-8 hours

**Week 2 Total:** ~17-23 hours

### Week 3: Polish & Quality
- **Day 1-2:** Group 7 (Code Generation) - 8-12 hours (optional)
- **Day 3-5:** Group 10 (Documentation & Testing) - 8-12 hours

**Week 3 Total:** ~16-24 hours

**Total Timeline:** 2-3 weeks for complete fix

---

## Quick Start: Critical Path (Minimum Viable Fix)

If time is limited, focus on these groups in order:

1. **Group 1** - Error Handling Foundation (12-14 hours) ⚠️ **MUST FIX**
2. **Group 2** - Configuration Cleanup (3-4 hours) ⚠️ **MUST FIX**
3. **Group 3** - Storage & Security (4-6 hours) ⚠️ **MUST FIX**
4. **Group 4** - Token Refresh (4-6 hours) ⚠️ **MUST FIX**
5. **Group 5** - Use Cases (6-8 hours) ⚠️ **MUST FIX**

**Minimum Viable Fix:** ~29-38 hours (1 week)

This addresses all **Critical** issues and makes the project production-ready.

---

## Notes

- **Dependencies:** Always complete groups in order when dependencies exist
- **Testing:** Add tests as you implement each group
- **Commits:** Commit after each group completion
- **Code Review:** Review each group before moving to next
- **Documentation:** Update docs as you fix issues

---

## Self-Contained Prompts for Each Group

Each group can be implemented independently using the detailed approach above. The prompts are structured to be self-contained with all necessary context.

