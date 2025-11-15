# Group 6: Result Type & Pattern Matching - Self-Contained Implementation Prompt

**Last Updated:** November 15, 2025

## Context

I need to improve the Result type implementation to use proper Dart 3.0 pattern matching and clarify the relationship between `ResultFailure` and `Failure` classes. Currently, `Result.when()` uses named parameters instead of pattern matching, and the naming relationship between `ResultFailure` and `Failure` classes is unclear.

## Current State

### Problems:
1. **Result.when() uses named parameters** - Not using Dart 3.0 pattern matching
2. **Naming inconsistency** - `ResultFailure` vs `Failure` classes relationship unclear
3. **Non-idiomatic pattern matching** - Should use switch expressions
4. **Type safety** - Could be improved with proper pattern matching

### Current Files:
- `lib/core/utils/result.dart` - Has Result with ResultFailure
- `lib/core/errors/failures.dart` - Has typed Failure classes
- `lib/features/auth/presentation/providers/auth_provider.dart` - Uses Result.when()

## Requirements

### 1. Update Result.when() Method
**File:** `lib/core/utils/result.dart`

- Use proper Dart 3.0 pattern matching with switch expressions
- Or document named parameter approach clearly
- Consider using `freezed` for union types (if implementing code generation)

### 2. Clarify ResultFailure vs Failure Naming
**File:** `lib/core/utils/result.dart`, `lib/core/errors/failures.dart`

- Document relationship between `ResultFailure` and `Failure` classes
- Update naming if needed for clarity
- Ensure consistent usage

### 3. Improve Type Safety
- Better pattern matching support
- Type-safe error handling
- Improved IDE support

## Implementation Details

### Option A: Use Pattern Matching (Recommended)
```dart
extension ResultExtensions<T> on Result<T> {
  R when<R>({
    required R Function(T data) success,
    required R Function(Failure failure) failure,
  }) {
    return switch (this) {
      Success<T>(:final data) => success(data),
      ResultFailure<T>(:final failure) => failure(failure),
    };
  }
}
```

### Option B: Keep Named Parameters (If Preferred)
```dart
extension ResultExtensions<T> on Result<T> {
  R when<R>({
    required R Function(T data) success,
    required R Function(Failure failure) failure,
  }) {
    if (this is Success<T>) {
      return success((this as Success<T>).data);
    } else {
      return failure((this as ResultFailure<T>).failure);
    }
  }
}
```

### Option C: Use Freezed (If Implementing Code Generation)
```dart
@freezed
sealed class Result<T> with _$Result<T> {
  const factory Result.success(T data) = Success<T>;
  const factory Result.failure(Failure failure) = FailureResult<T>;
}
```

## Testing Requirements

1. **Test Result.when() usage**
   - Test pattern matching
   - Test all branches
   - Test type safety

2. **Test naming consistency**
   - Verify ResultFailure and Failure relationship
   - Test usage patterns

## Success Criteria

- ✅ Result.when() uses proper pattern matching or is clearly documented
- ✅ Naming relationship between ResultFailure and Failure is clear
- ✅ Consistent usage throughout codebase
- ✅ Type safety improved
- ✅ All tests pass

## Files to Modify

1. `lib/core/utils/result.dart` - Update when() method or documentation
2. `lib/core/errors/failures.dart` - Document relationship

## Dependencies

- Group 1 (Error Handling) - Result type should use typed failures

---

## Common Mistakes to Avoid

### ❌ Don't break existing code
- Ensure backward compatibility
- Update all usages if changing API

### ❌ Don't mix patterns
- Choose one approach (pattern matching or named params)
- Be consistent throughout

### ❌ Don't lose type information
- Preserve type safety
- Don't use dynamic

---

## Edge Cases to Handle

### 1. Null Data in Success
- Handle nullable T types
- Type-safe null handling

### 2. Unknown Failure Types
- Handle all Failure subtypes
- Default case for unknown failures

---

## Expected Deliverables

Provide responses in this order:

### 1. Updated Result Type (Complete Code)

**1.1. `lib/core/utils/result.dart`**
- Updated when() method
- Pattern matching or clear documentation
- Type safety improvements

### 2. Documentation Updates

**2.1. Naming Relationship Documentation**
- Document ResultFailure vs Failure
- Usage guidelines
- Examples

### 3. Test File Examples

**3.1. `test/core/utils/result_test.dart`**
- Test when() method
- Test pattern matching
- Test type safety

---

## Implementation Checklist

Before submitting, verify:

- [ ] Result.when() updated or documented
- [ ] Naming relationship clear
- [ ] Type safety maintained
- [ ] All existing code works
- [ ] Tests pass
- [ ] Documentation updated

