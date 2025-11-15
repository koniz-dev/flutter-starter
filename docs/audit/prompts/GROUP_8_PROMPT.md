# Group 8: Unused Dependencies Cleanup - Self-Contained Implementation Prompt

**Last Updated:** November 15, 2025

## Context

I need to clean up unused dependencies from `pubspec.yaml`. Currently, 10+ packages are declared but never imported or used, increasing app size and dependency complexity. This group requires a decision: remove unused dependencies OR implement them.

## Current State

### Problems:
1. **10+ unused dependencies** - Declared but never used
2. **Increased app size** - Unnecessary packages bloat the app
3. **Confusion** - Developers don't know which packages are actually used
4. **Security risk** - Some unused packages (flutter_secure_storage) should be used

### Unused Dependencies:
- `hive`, `hive_flutter` - Not used
- `go_router`, `go_router_builder` - Not used
- `retrofit`, `retrofit_generator` - Not used
- `cached_network_image` - Not used
- `flutter_screenutil` - Not used
- `shimmer` - Not used
- `logger` - Not used (only in comment)
- `intl` - Not used (if not planning localization)
- `freezed_annotation`, `json_annotation` - Not used (unless implementing Group 7)
- `riverpod_annotation` - Not used (optional)

## Requirements

### Decision Required: Remove OR Implement

**Option A: Remove Unused Dependencies (Recommended)**
- Clean up `pubspec.yaml`
- Remove unused packages
- Reduce app size
- Clear dependency strategy

**Option B: Implement Unused Dependencies**
- Implement all declared features
- Use all dependencies as intended
- More work but complete implementation

### Recommended: Option A (Remove for now, add back when needed)

### 1. Remove Unused Packages
**File:** `pubspec.yaml`

Remove if not planning to use:
- `hive`, `hive_flutter`
- `go_router`, `go_router_builder`
- `retrofit`, `retrofit_generator`
- `cached_network_image`
- `flutter_screenutil`
- `shimmer`
- `logger` (or implement it)
- `intl` (if not planning localization)

### 2. Keep But Document
- `equatable` - Used in failures, consider for entities
- `freezed_annotation`, `json_annotation` - If implementing Group 7
- `riverpod_annotation` - Optional, can keep manual providers

### 3. Update Documentation
- Document removed dependencies
- Note when to add back if needed
- Update README with dependency strategy

## Implementation Details

### pubspec.yaml Cleanup:
```yaml
dependencies:
  # REMOVE if not using:
  # hive: ^2.2.3
  # hive_flutter: ^1.1.0
  # go_router: ^17.0.0
  # retrofit: ^4.9.0
  # cached_network_image: ^3.4.1
  # flutter_screenutil: ^5.9.3
  # shimmer: ^3.0.0
  # logger: ^2.6.2
  # intl: ^0.20.2 (if not localizing)

  # KEEP:
  flutter_riverpod: ^3.0.3
  dio: ^5.9.0
  shared_preferences: ^2.5.3
  flutter_secure_storage: ^9.2.4 # Should be used (Group 3)
  equatable: ^2.0.7
  # ... other used packages

dev_dependencies:
  # REMOVE if not using:
  # go_router_builder: ^4.1.1
  # retrofit_generator: ^10.1.4

  # KEEP if implementing Group 7:
  freezed: ^3.2.3
  json_serializable: ^6.11.1
  build_runner: ^2.10.3
```

### Verification Script (Optional):
```bash
# Check for unused imports
grep -r "import.*hive" lib/
grep -r "import.*go_router" lib/
# ... check each package
```

## Testing Requirements

1. **Verify app still works**
   - Run app after removing dependencies
   - Check for compilation errors
   - Test all features

2. **Verify no broken imports**
   - Check for import errors
   - Remove unused imports
   - Clean up code

3. **Test dependency resolution**
   - Run `flutter pub get`
   - Verify no conflicts
   - Check for warnings

## Success Criteria

- ✅ No unused dependencies in pubspec.yaml
- ✅ All declared dependencies are used
- ✅ App size reduced
- ✅ Clear dependency strategy
- ✅ Documentation updated
- ✅ All tests pass

## Files to Modify

1. `pubspec.yaml` - Remove unused dependencies
2. `README.md` - Document dependency decisions
3. Any files with unused imports - Clean up

## Dependencies

- None (standalone cleanup)

---

## Common Mistakes to Avoid

### ❌ Don't remove dependencies that are actually used
- Check all imports before removing
- Verify transitive dependencies
- Test thoroughly

### ❌ Don't break existing functionality
- Ensure app still works
- Test all features
- Check for runtime errors

### ❌ Don't remove security-critical dependencies
- Keep `flutter_secure_storage` (should be used)
- Don't remove security-related packages

### ❌ Don't forget dev dependencies
- Check dev_dependencies too
- Remove unused code generators

---

## Edge Cases to Handle

### 1. Transitive Dependencies
- Some packages may be required by others
- Check dependency tree
- Don't break transitive deps

### 2. Future Plans
- Document why removed
- Note when to add back
- Keep removal rationale

### 3. Platform-Specific Dependencies
- Some packages may be platform-specific
- Test on all platforms
- Verify platform compatibility

---

## Expected Deliverables

Provide responses in this order:

### 1. Updated pubspec.yaml (Complete File)

**1.1. `pubspec.yaml`**
- Complete file with unused deps removed
- Clear organization
- Comments explaining kept packages

### 2. Updated Documentation

**2.1. `README.md` or `DEPENDENCIES.md`**
- Document removed dependencies
- Rationale for removal
- When to add back if needed

### 3. Cleanup Summary

**3.1. Removed Dependencies List**
- List of removed packages
- Reason for removal
- Alternative if needed

### 4. Verification Notes

**4.1. Testing Results**
- App still works
- No broken imports
- No compilation errors

---

## Implementation Checklist

Before submitting, verify:

- [ ] Unused dependencies removed
- [ ] All used dependencies kept
- [ ] App compiles and runs
- [ ] No broken imports
- [ ] Documentation updated
- [ ] Dependency strategy clear
- [ ] README updated

