# Group 7: Code Generation Implementation - Self-Contained Implementation Prompt

**Last Updated:** November 15, 2025

## Context

I need to implement code generation for models and state classes using `@freezed` and `@JsonSerializable`. Currently, `freezed_annotation` and `json_annotation` are declared but not used. Models use manual `fromJson`/`toJson` methods and state classes manually implement `copyWith`.

## Current State

### Problems:
1. **@freezed not used** - AuthState manually implements copyWith
2. **@JsonSerializable not used** - Models use manual JSON serialization
3. **More boilerplate** - Manual implementations are error-prone
4. **Inconsistent with dependencies** - Code generation packages declared but unused

### Current Files:
- `lib/features/auth/presentation/providers/auth_provider.dart` - AuthState with manual copyWith
- `lib/features/auth/data/models/user_model.dart` - Manual fromJson/toJson
- `lib/features/auth/data/models/auth_response_model.dart` - Manual fromJson/toJson
- `lib/core/utils/result.dart` - Could use @freezed (optional)

## Requirements

### 1. Implement @freezed for AuthState
**File:** `lib/features/auth/presentation/providers/auth_provider.dart`

- Add `@freezed` annotation
- Run `build_runner`
- Remove manual `copyWith` implementation
- Update all usages

### 2. Implement @JsonSerializable for Models
**Files:** Model files

- Add `@JsonSerializable` to `UserModel`
- Add `@JsonSerializable` to `AuthResponseModel`
- Run `build_runner`
- Remove manual `fromJson`/`toJson` methods
- Update all usages

### 3. Optional: Use @freezed for Result Type
**File:** `lib/core/utils/result.dart`

- Consider converting to freezed union type
- Better pattern matching support
- Or keep current sealed class approach

## Implementation Details

### AuthState with @freezed:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';

part 'auth_provider.freezed.dart';

@freezed
class AuthState with _$AuthState {
  const factory AuthState({
    User? user,
    @Default(false) bool isLoading,
    String? error,
  }) = _AuthState;
}
```

### UserModel with @JsonSerializable:
```dart
import 'package:json_annotation/json_annotation.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    super.name,
    super.avatarUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  Map<String, dynamic> toJson() => _$UserModelToJson(this);
}
```

### Build Command:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## Testing Requirements

1. **Test generated code**
   - Verify freezed code generation
   - Verify JSON serialization
   - Test copyWith works

2. **Test JSON serialization**
   - Test fromJson
   - Test toJson
   - Test edge cases

3. **Test state management**
   - Test AuthState copyWith
   - Test immutability
   - Test equality

## Success Criteria

- ✅ AuthState uses @freezed
- ✅ Models use @JsonSerializable
- ✅ Generated code works correctly
- ✅ Less boilerplate code
- ✅ All tests pass
- ✅ No manual implementations

## Files to Modify

1. `lib/features/auth/presentation/providers/auth_provider.dart` - Add @freezed
2. `lib/features/auth/data/models/user_model.dart` - Add @JsonSerializable
3. `lib/features/auth/data/models/auth_response_model.dart` - Add @JsonSerializable
4. `lib/core/utils/result.dart` - Optional @freezed

## Dependencies

- `freezed` (dev dependency)
- `json_serializable` (dev dependency)
- `build_runner` (dev dependency)
- `freezed_annotation` (dependency)
- `json_annotation` (dependency)

---

## Common Mistakes to Avoid

### ❌ Don't forget part directives
- Add `part` directives for generated files
- File names must match

### ❌ Don't forget to run build_runner
- Run after adding annotations
- Use --delete-conflicting-outputs flag

### ❌ Don't mix manual and generated code
- Remove manual implementations
- Use only generated code

### ❌ Don't forget to commit generated files
- Add .g.dart and .freezed.dart files
- Or add to .gitignore if preferred

---

## Edge Cases to Handle

### 1. Nullable Fields
- Handle nullable types in JSON
- Proper null handling in serialization

### 2. Custom Converters
- Date/time serialization
- Enum serialization
- Custom type converters

### 3. Nested Objects
- Complex nested structures
- Circular references (if any)

---

## Expected Deliverables

Provide responses in this order:

### 1. Updated Files with Annotations (Complete Code)

**1.1. `lib/features/auth/presentation/providers/auth_provider.dart`**
- Complete file with @freezed
- Part directive added
- Manual code removed

**1.2. `lib/features/auth/data/models/user_model.dart`**
- Complete file with @JsonSerializable
- Part directive added
- Manual methods removed

**1.3. `lib/features/auth/data/models/auth_response_model.dart`**
- Complete file with @JsonSerializable
- Part directive added
- Manual methods removed

### 2. Build Runner Instructions

**2.1. Build Commands**
- Exact commands to run
- Expected output
- Troubleshooting tips

### 3. Generated Files (Optional)

**3.1. Generated file examples**
- Show generated code structure
- Verify correctness

### 4. Test File Examples

**4.1. `test/features/auth/data/models/user_model_test.dart`**
- Test JSON serialization
- Test fromJson/toJson

**4.2. `test/features/auth/presentation/providers/auth_provider_test.dart`**
- Test AuthState copyWith
- Test immutability

---

## Implementation Checklist

Before submitting, verify:

- [ ] @freezed added to AuthState
- [ ] @JsonSerializable added to models
- [ ] Part directives added
- [ ] build_runner executed
- [ ] Generated files created
- [ ] Manual code removed
- [ ] All tests pass
- [ ] No compilation errors

