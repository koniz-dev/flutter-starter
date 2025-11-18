# Migration Guides

This directory contains comprehensive migration guides for the Flutter starter project.

## Available Guides

### From Other Architectures

1. **[From MVC to Clean Architecture](from-mvc-to-clean-architecture.md)**
   - Step-by-step guide to migrate from MVC architecture
   - Converting controllers to use cases
   - Moving business logic to domain layer
   - Setting up Clean Architecture layers

2. **[From BLoC to Riverpod](from-bloc-to-riverpod.md)**
   - Migrating from BLoC/Cubit to Riverpod
   - Converting events to methods
   - Replacing BlocBuilder with ConsumerWidget
   - Updating dependency injection

3. **[From GetX to This Setup](from-getx-to-this-setup.md)**
   - Migrating from GetX to Clean Architecture + Riverpod
   - Replacing GetxController with Notifier
   - Converting GetX navigation to standard Flutter
   - Migrating GetStorage to StorageService

### Upgrading This Starter

4. **[Upgrading This Starter](upgrading-this-starter.md)**
   - Version upgrade process
   - Breaking changes documentation
   - Migration scripts
   - Troubleshooting upgrades

### Customization

5. **[Customization Guide](customization-guide.md)**
   - Removing unused features
   - Adding custom features
   - Adapting to specific needs
   - Best practices

## Quick Start

### Choosing the Right Guide

- **Migrating from MVC?** → Start with [From MVC to Clean Architecture](from-mvc-to-clean-architecture.md)
- **Migrating from BLoC?** → Start with [From BLoC to Riverpod](from-bloc-to-riverpod.md)
- **Migrating from GetX?** → Start with [From GetX to This Setup](from-getx-to-this-setup.md)
- **Upgrading this starter?** → See [Upgrading This Starter](upgrading-this-starter.md)
- **Customizing the starter?** → See [Customization Guide](customization-guide.md)

## Migration Process Overview

### General Migration Steps

1. **Understand the Differences**
   - Review architecture differences
   - Understand new patterns
   - Identify key changes

2. **Plan Your Migration**
   - Create a migration checklist
   - Prioritize features
   - Set up a backup

3. **Migrate Incrementally**
   - Start with one feature at a time
   - Test after each migration
   - Keep old code until migration is complete

4. **Update Dependencies**
   - Update `pubspec.yaml`
   - Run `flutter pub get`
   - Resolve conflicts

5. **Update Code**
   - Follow step-by-step guides
   - Use migration scripts (if available)
   - Fix breaking changes

6. **Test Thoroughly**
   - Run unit tests
   - Test on devices
   - Verify all features work

7. **Clean Up**
   - Remove old code
   - Update documentation
   - Commit changes

## Common Patterns

### State Management Migration

**Before (Various Patterns):**
```dart
// MVC: setState
setState(() => _count++);

// BLoC: emit
emit(state + 1);

// GetX: .obs
count.value++;
```

**After (Riverpod):**
```dart
// Riverpod: state assignment
state = state + 1;
```

### Dependency Injection Migration

**Before (Various Patterns):**
```dart
// MVC: Direct instantiation
final service = MyService();

// BLoC: BlocProvider
final bloc = context.read<MyBloc>();

// GetX: Get.find()
final service = Get.find<MyService>();
```

**After (Riverpod):**
```dart
// Riverpod: ref.read/ref.watch
final service = ref.read(myServiceProvider);
```

### Error Handling Migration

**Before (Various Patterns):**
```dart
// try-catch
try {
  final data = await fetchData();
} catch (e) {
  print('Error: $e');
}

// Null returns
final user = await login();
if (user == null) {
  // Handle error
}
```

**After (Result Pattern):**
```dart
// Result<T> pattern
final result = await loginUseCase(email, password);
result.when(
  success: (user) => handleSuccess(user),
  failureCallback: (failure) => handleFailure(failure),
);
```

## Best Practices

### 1. Incremental Migration

- Don't try to migrate everything at once
- Migrate one feature/module at a time
- Test after each migration step

### 2. Keep Old Code

- Keep old code until migration is complete
- Use feature flags to switch between old/new
- Remove old code only after verification

### 3. Test Thoroughly

- Write tests before migration
- Update tests during migration
- Verify all tests pass after migration

### 4. Document Changes

- Document what changed
- Note any breaking changes
- Update team documentation

### 5. Get Help

- Review migration guides
- Check examples in codebase
- Ask for help if stuck

## Troubleshooting

### Common Issues

**Issue: Dependency conflicts**
- Solution: Review `pubspec.yaml`
- Use `flutter pub deps` to check conflicts
- Consider `dependency_overrides` if needed

**Issue: Compilation errors**
- Solution: Review breaking changes
- Update code to use new APIs
- Check migration guides

**Issue: Runtime errors**
- Solution: Check error logs
- Review error handling
- Test on clean project

**Issue: Tests failing**
- Solution: Update test mocks
- Update test expectations
- Review test documentation

## Related Documentation

- [Understanding the Codebase](../understanding-codebase.md) - Architecture overview
- [Common Patterns](../../api/examples/common-patterns.md) - Common patterns
- [Adding Features](../../api/examples/adding-features.md) - Adding new features
- [Getting Started](../getting-started.md) - Initial setup

## Getting Help

If you encounter issues during migration:

1. **Review the Guides** - Check relevant migration guide
2. **Check Examples** - Look at existing code in the starter
3. **Search Issues** - Check GitHub for similar issues
4. **Ask for Help** - Create a GitHub issue with details

## Contributing

If you find issues or have improvements:

1. Create a GitHub issue
2. Provide detailed information
3. Suggest improvements
4. Contribute fixes via pull request

