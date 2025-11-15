# Group 9: UI/UX Improvements - Self-Contained Implementation Prompt

**Last Updated:** November 15, 2025

## Context

I need to improve the UI/UX layer by adding proper validation, creating missing screens, and fixing state management issues. Currently, login screen has basic validation, register screen is missing, and AuthNotifier has incomplete error handling.

## Current State

### Problems:
1. **Missing validation** - Login screen doesn't use Validators class
2. **Missing RegisterScreen** - No UI for registration
3. **Incomplete error handling** - AuthNotifier doesn't clear errors properly
4. **Missing loading states** - Only login has loading state
5. **Navigation inconsistency** - ContextExtensions uses MaterialApp Navigator but go_router declared

### Current Files:
- `lib/features/auth/presentation/screens/login_screen.dart` - Basic validation
- `lib/features/auth/presentation/providers/auth_provider.dart` - Incomplete methods
- `lib/shared/extensions/context_extensions.dart` - Uses MaterialApp Navigator
- `lib/core/utils/validators.dart` - Exists but not used

## Requirements

### 1. Improve Login Screen Validation
**File:** `lib/features/auth/presentation/screens/login_screen.dart`

- Use `Validators.isValidEmail()` for email
- Use `Validators.isValidPassword()` for password
- Show specific error messages
- Improve UX with helpful feedback

### 2. Create RegisterScreen
**File:** `lib/features/auth/presentation/screens/register_screen.dart` (NEW)

- Similar to LoginScreen
- Use `RegisterUseCase`
- Proper validation
- Error handling

### 3. Fix AuthNotifier Error Handling
**File:** `lib/features/auth/presentation/providers/auth_provider.dart`

- Clear error state before new operations
- Reset error on success
- Handle state transitions properly

### 4. Add Loading States
**File:** `lib/features/auth/presentation/providers/auth_provider.dart`

- Add loading for register, logout, refreshToken
- Update UI to show loading indicators
- Handle loading state transitions

### 5. Clarify Logging Flags
**File:** `lib/core/config/app_config.dart`

- Document `enableLogging` vs `enableHttpLogging`
- Or consolidate if redundant

### 6. Update Navigation Extensions
**File:** `lib/shared/extensions/context_extensions.dart`

- Document current approach
- Or update to go_router if implementing

## Implementation Details

### Login Screen Validation:
```dart
validator: (value) {
  if (value == null || value.isEmpty) {
    return 'Please enter your email';
  }
  if (!Validators.isValidEmail(value)) {
    return 'Please enter a valid email address';
  }
  return null;
},
```

### RegisterScreen Structure:
```dart
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      await ref.read(authNotifierProvider.notifier).register(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    
    // Similar to LoginScreen but with name field
  }
}
```

### AuthNotifier Error Handling:
```dart
Future<void> login(String email, String password) async {
  // Clear previous error
  state = state.copyWith(isLoading: true, error: null);
  
  final loginUseCase = ref.read(loginUseCaseProvider);
  final result = await loginUseCase(email, password);
  
  result.when(
    success: (user) {
      state = state.copyWith(
        user: user,
        isLoading: false,
        error: null, // Clear error on success
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
```

## Testing Requirements

1. **Test validation**
   - Test email validation
   - Test password validation
   - Test error messages

2. **Test RegisterScreen**
   - Test registration flow
   - Test validation
   - Test error handling

3. **Test error state handling**
   - Test error clearing
   - Test error display
   - Test state transitions

4. **Test loading states**
   - Test loading indicators
   - Test loading for all operations

## Success Criteria

- ✅ Proper validation in login/register screens
- ✅ Register screen implemented
- ✅ Error handling works correctly
- ✅ Loading states for all operations
- ✅ Clear logging flag documentation
- ✅ Navigation documented or updated
- ✅ All tests pass

## Files to Create

1. `lib/features/auth/presentation/screens/register_screen.dart`

## Files to Modify

1. `lib/features/auth/presentation/screens/login_screen.dart` - Improve validation
2. `lib/features/auth/presentation/providers/auth_provider.dart` - Fix error handling, add loading
3. `lib/core/config/app_config.dart` - Document logging flags
4. `lib/shared/extensions/context_extensions.dart` - Document or update navigation

## Dependencies

- Group 5 (Use Cases) - For RegisterUseCase

---

## Common Mistakes to Avoid

### ❌ Don't show technical error messages
- Make errors user-friendly
- Don't expose internal details

### ❌ Don't forget to clear errors
- Clear before new operations
- Reset on success

### ❌ Don't ignore loading states
- Show loading for all async operations
- Prevent multiple submissions

### ❌ Don't duplicate validation logic
- Use Validators class
- Don't repeat validation code

---

## Edge Cases to Handle

### 1. Network Errors During Registration
- Handle gracefully
- Show user-friendly messages
- Allow retry

### 2. Form Validation Edge Cases
- Empty fields
- Invalid formats
- Special characters

### 3. Concurrent Operations
- Prevent multiple submissions
- Handle loading state properly

---

## Expected Deliverables

Provide responses in this order:

### 1. New RegisterScreen (Complete Code)

**1.1. `lib/features/auth/presentation/screens/register_screen.dart`**
- Complete implementation
- Proper validation
- Error handling
- Loading states

### 2. Updated LoginScreen (Changes Only)

**2.1. `lib/features/auth/presentation/screens/login_screen.dart`**
- Show only validation improvements
- Clear before/after context

### 3. Updated AuthNotifier (Changes Only)

**3.1. `lib/features/auth/presentation/providers/auth_provider.dart`**
- Show error handling fixes
- Loading state additions
- Clear before/after context

### 4. Updated Documentation (Changes Only)

**4.1. `lib/core/config/app_config.dart`**
- Logging flag documentation
- Clear explanation

### 5. Test File Examples

**5.1. `test/features/auth/presentation/screens/login_screen_test.dart`**
- Test validation
- Test error display

**5.2. `test/features/auth/presentation/screens/register_screen_test.dart`**
- Test registration flow
- Test validation

---

## Implementation Checklist

Before submitting, verify:

- [ ] Login screen uses Validators
- [ ] Register screen created
- [ ] Error handling fixed
- [ ] Loading states added
- [ ] Logging flags documented
- [ ] Navigation documented
- [ ] All tests pass
- [ ] UX improved

