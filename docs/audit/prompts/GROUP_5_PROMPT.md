# Group 5: Use Cases & Clean Architecture - Self-Contained Implementation Prompt

**Last Updated:** November 15, 2025

## Context

I need to complete the Clean Architecture implementation by creating missing use cases and updating the presentation layer. Currently, only `LoginUseCase` exists, but the repository has methods for register, logout, refreshToken, getCurrentUser, and isAuthenticated. The presentation layer should use use cases, not repositories directly.

## Current State

### Problems:
1. **Missing use cases** - Only LoginUseCase exists, others missing
2. **Missing use case providers** - No providers for other use cases
3. **AuthNotifier incomplete** - Only has login() method
4. **Direct repository access** - Presentation layer should use use cases
5. **Incomplete Clean Architecture** - Business logic should go through use cases

### Current Files:
- `lib/features/auth/domain/usecases/login_usecase.dart` - Only use case exists
- `lib/core/di/providers.dart` - Only loginUseCaseProvider exists
- `lib/features/auth/presentation/providers/auth_provider.dart` - Only login() method
- `lib/features/auth/domain/repositories/auth_repository.dart` - Has all methods

## Requirements

### 1. Create Missing Use Cases
**Files:** New files in `lib/features/auth/domain/usecases/`

- `register_usecase.dart` - RegisterUseCase
- `logout_usecase.dart` - LogoutUseCase
- `refresh_token_usecase.dart` - RefreshTokenUseCase
- `get_current_user_usecase.dart` - GetCurrentUserUseCase
- `is_authenticated_usecase.dart` - IsAuthenticatedUseCase

### 2. Create Use Case Providers
**File:** `lib/core/di/providers.dart`

- Add providers for all use cases
- Follow same pattern as `loginUseCaseProvider`

### 3. Update AuthNotifier
**File:** `lib/features/auth/presentation/providers/auth_provider.dart`

- Add `register()` method
- Add `logout()` method
- Add `refreshToken()` method
- Add `getCurrentUser()` method
- Add `isAuthenticated()` method
- Use use cases, not repository directly
- Handle loading and error states properly

### 4. Update State Management
- Clear error state before new operations
- Reset error on success
- Handle loading state transitions
- Update state properly for all operations

## Implementation Details

### Use Case Structure (Example: RegisterUseCase):
```dart
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/domain/repositories/auth_repository.dart';

class RegisterUseCase {
  RegisterUseCase(this.repository);

  final AuthRepository repository;

  Future<Result<User>> call(
    String email,
    String password,
    String name,
  ) async {
    return repository.register(email, password, name);
  }
}
```

### Provider Structure:
```dart
// In providers.dart
final registerUseCaseProvider = Provider<RegisterUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return RegisterUseCase(repository);
});

final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return LogoutUseCase(repository);
});

// ... other providers
```

### AuthNotifier Update:
```dart
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    return const AuthState();
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    
    final loginUseCase = ref.read(loginUseCaseProvider);
    final result = await loginUseCase(email, password);
    
    result.when(
      success: (user) {
        state = state.copyWith(
          user: user,
          isLoading: false,
          error: null,
        );
      },
      failure: (message, code) {
        state = state.copyWith(
          isLoading: false,
          error: message,
        );
      },
    );
  }

  Future<void> register(
    String email,
    String password,
    String name,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    
    final registerUseCase = ref.read(registerUseCaseProvider);
    final result = await registerUseCase(email, password, name);
    
    result.when(
      success: (user) {
        state = state.copyWith(
          user: user,
          isLoading: false,
          error: null,
        );
      },
      failure: (message, code) {
        state = state.copyWith(
          isLoading: false,
          error: message,
        );
      },
    );
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, error: null);
    
    final logoutUseCase = ref.read(logoutUseCaseProvider);
    final result = await logoutUseCase();
    
    result.when(
      success: (_) {
        state = const AuthState(
          user: null,
          isLoading: false,
          error: null,
        );
      },
      failure: (message, code) {
        state = state.copyWith(
          isLoading: false,
          error: message,
        );
      },
    );
  }

  Future<void> refreshToken() async {
    final refreshTokenUseCase = ref.read(refreshTokenUseCaseProvider);
    final result = await refreshTokenUseCase();
    
    result.when(
      success: (_) {
        // Token refreshed, no state change needed
      },
      failure: (message, code) {
        // Refresh failed, might need to logout
        if (code == 'REFRESH_TOKEN_EXPIRED') {
          logout();
        }
      },
    );
  }

  Future<void> getCurrentUser() async {
    state = state.copyWith(isLoading: true, error: null);
    
    final getCurrentUserUseCase = ref.read(getCurrentUserUseCaseProvider);
    final result = await getCurrentUserUseCase();
    
    result.when(
      success: (user) {
        state = state.copyWith(
          user: user,
          isLoading: false,
          error: null,
        );
      },
      failure: (message, code) {
        state = state.copyWith(
          isLoading: false,
          error: message,
        );
      },
    );
  }

  Future<bool> isAuthenticated() async {
    final isAuthenticatedUseCase = ref.read(isAuthenticatedUseCaseProvider);
    final result = await isAuthenticatedUseCase();
    
    return result.when(
      success: (isAuth) => isAuth,
      failure: (_, __) => false,
    );
  }
}
```

## Testing Requirements

1. **Unit tests for each use case**
   - Test success scenarios
   - Test failure scenarios
   - Test repository interaction

2. **Test AuthNotifier**
   - Test all methods
   - Test state transitions
   - Test error handling
   - Test loading states

3. **Integration tests**
   - Test use case → repository flow
   - Test complete auth flows

## Success Criteria

- ✅ All auth operations have use cases
- ✅ All use cases have providers
- ✅ AuthNotifier uses use cases (not repository)
- ✅ All auth operations available in UI layer
- ✅ Proper state management
- ✅ Error handling works correctly
- ✅ Loading states handled properly
- ✅ All tests pass

## Files to Create

1. `lib/features/auth/domain/usecases/register_usecase.dart`
2. `lib/features/auth/domain/usecases/logout_usecase.dart`
3. `lib/features/auth/domain/usecases/refresh_token_usecase.dart`
4. `lib/features/auth/domain/usecases/get_current_user_usecase.dart`
5. `lib/features/auth/domain/usecases/is_authenticated_usecase.dart`

## Files to Modify

1. `lib/core/di/providers.dart` - Add use case providers
2. `lib/features/auth/presentation/providers/auth_provider.dart` - Add all methods

## Dependencies

- Group 1 (Error Handling) - For proper Result type with typed failures

---

## Common Mistakes to Avoid

### ❌ Don't access repository directly from presentation
- Always use use cases
- Keep Clean Architecture layers separate

### ❌ Don't forget error state management
- Clear errors before new operations
- Reset errors on success
- Handle error state transitions

### ❌ Don't ignore loading states
- Set loading before operations
- Clear loading on completion
- Handle loading for all operations

### ❌ Don't duplicate business logic
- Keep logic in use cases
- Don't repeat in notifier
- Use cases are single source of truth

### ❌ Don't forget to handle edge cases
- Null user scenarios
- Token expiry scenarios
- Network failures

---

## Edge Cases to Handle

### 1. Concurrent Operations
- Multiple operations at once
- Prevent state conflicts
- Handle loading state properly

### 2. Token Refresh During Other Operations
- Refresh happens in background
- Don't block other operations
- Update state appropriately

### 3. User State Consistency
- User logged out in another session
- Token expired during operation
- Handle state synchronization

### 4. Network Failures
- Operation fails mid-way
- State should reflect failure
- Allow retry

### 5. Partial Success
- Some operations succeed partially
- Handle rollback if needed
- Maintain state consistency

---

## Expected Deliverables

Provide responses in this order:

### 1. Five New Use Case Files (Complete Code)

**1.1-1.5. Use case files**
- Complete implementation for each use case
- Proper error handling
- Type-safe returns

### 2. Updated Providers (Changes Only)

**2.1. `lib/core/di/providers.dart`**
- Show only the changes
- All use case providers
- Clear before/after context

### 3. Updated AuthNotifier (Complete Code)

**3.1. `lib/features/auth/presentation/providers/auth_provider.dart`**
- Complete implementation
- All methods added
- Proper state management
- Error handling

### 4. Test File Examples (At Least 3)

**4.1. `test/features/auth/domain/usecases/register_usecase_test.dart`**
- Unit test for RegisterUseCase
- Success and failure scenarios

**4.2. `test/features/auth/presentation/providers/auth_provider_test.dart`**
- Test all AuthNotifier methods
- State transition tests
- Error handling tests

**4.3. `test/features/auth/integration/auth_flow_test.dart`**
- Integration test for complete auth flow
- Use case → repository → data source

### 5. Migration Notes

**5.1. Breaking Changes**
- AuthNotifier API changes
- New methods added

**5.2. Migration Steps**
- Update UI to use new methods
- Test all auth operations
- Verify state management

---

## Implementation Checklist

Before submitting, verify:

- [ ] All use cases created
- [ ] All use case providers created
- [ ] AuthNotifier has all methods
- [ ] Use cases used (not repository)
- [ ] State management proper
- [ ] Error handling correct
- [ ] Loading states handled
- [ ] All tests pass
- [ ] Edge cases handled
- [ ] Clean Architecture maintained

