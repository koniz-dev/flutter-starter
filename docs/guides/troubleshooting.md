# Troubleshooting

This guide covers common issues, solutions, and frequently asked questions.

## Common Issues

### 1. Code Generation Errors

**Problem**: `build_runner` fails or generates incorrect code.

**Solutions:**
```bash
# Clean and regenerate
flutter clean
flutter pub get
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

**If issues persist:**
- Check for syntax errors in `@freezed` or `@JsonSerializable` classes
- Ensure all required imports are present
- Delete generated files (`.freezed.dart`, `.g.dart`) and regenerate

### 2. Configuration Not Loading

**Problem**: Environment variables not being read.

**Solutions:**
1. Ensure `.env` file exists in project root
2. Check `pubspec.yaml` includes `.env.example` in assets
3. Verify `EnvConfig.load()` is called in `main()` before `runApp()`
4. For `--dart-define`, ensure flags are passed correctly
5. Do a full restart (not hot reload) after changing `.env`

**Debug:**
```dart
if (AppConfig.isDebugMode) {
  AppConfig.printConfig(); // Prints all config values
}
```

### 3. Provider Not Found Errors

**Problem**: `ProviderNotFoundException` when accessing providers.

**Solutions:**
1. Ensure widget is wrapped in `ProviderScope` or `UncontrolledProviderScope`
2. Check provider is defined in `lib/core/di/providers.dart`
3. Verify provider name is correct (case-sensitive)
4. Ensure provider is registered before use

### 4. Network/API Errors

**Problem**: API calls failing or timing out.

**Solutions:**
1. Check `BASE_URL` in configuration
2. Verify network connectivity
3. Check API timeout settings in `AppConfig`
4. Review interceptor logs (if HTTP logging enabled)
5. Verify authentication tokens are valid

### 5. Storage Errors

**Problem**: Storage operations failing.

**Solutions:**
1. Ensure `storageInitializationProvider` is awaited in `main()`
2. Check platform permissions (Android/iOS)
3. Verify storage keys are correct
4. For secure storage, check platform-specific setup

### 6. Test Failures

**Problem**: Tests failing after changes.

**Solutions:**
```bash
# Run tests with verbose output
flutter test --verbose

# Run specific test file
flutter test test/path/to/test.dart

# Clean and re-run
flutter clean
flutter pub get
flutter test
```

**Common causes:**
- Missing mocks
- Provider not initialized in tests
- Async operations not awaited
- State not reset between tests

### 7. Import Errors

**Problem**: Cannot find imports or "file not found" errors.

**Solutions:**
1. Run `flutter pub get`
2. Run code generation: `flutter pub run build_runner build`
3. Restart IDE/analysis server
4. Check file paths are correct
5. Verify `analysis_options.yaml` settings

### 8. Hot Reload Not Working

**Problem**: Changes not reflected after hot reload.

**Solutions:**
1. Some changes require hot restart:
   - Configuration changes
   - Provider changes
   - Static variable changes
2. Use hot restart (`R` in terminal) instead
3. If still not working, do a full restart

## FAQ

**Q: How do I add a new dependency?**
A: Add it to `pubspec.yaml`, run `flutter pub get`, and update documentation if it's a major addition.

**Q: How do I debug provider state?**
A: Use Riverpod DevTools or add debug prints in provider build methods. Check `ref.watch` vs `ref.read` usage.

**Q: When should I use `ref.read` vs `ref.watch`?**
A: Use `ref.read` for one-time access (callbacks). Use `ref.watch` for reactive access (in build methods).

**Q: How do I test providers?**
A: Use `ProviderScope` in tests and provide mock dependencies. See test examples in `test/` directory.

**Q: How do I handle errors in UI?**
A: Use `Result.when()` to handle success/failure. Show user-friendly messages based on failure type.

**Q: Can I use other state management solutions?**
A: This project uses Riverpod. If you need alternatives, discuss with the team first as it affects architecture.

**Q: How do I add environment-specific code?**
A: Use `AppConfig.isDevelopment`, `AppConfig.isStaging`, or `AppConfig.isProduction` to conditionally execute code.

**Q: How do I add new configuration variables?**
A: Add to `EnvConfig` for loading, then add typed getter in `AppConfig`. Update `.env.example` and documentation.

## Where to Get Help

1. **Documentation**:
   - [API Documentation](../api/README.md)
   - [Common Patterns](../api/examples/common-patterns.md)
   - [Architecture Docs](../architecture/) (if available)

2. **Code Examples**:
   - Check existing features (e.g., `lib/features/auth/`)
   - Review test files for usage patterns
   - See [Examples](../api/examples/)

3. **Team Resources**:
   - Ask in team chat/Slack
   - Create an issue in the repository
   - Request code review early for guidance

4. **External Resources**:
   - [Flutter Documentation](https://docs.flutter.dev/)
   - [Riverpod Documentation](https://riverpod.dev/)
   - [Dart Documentation](https://dart.dev/)

## Next Steps

- ✅ Review [Getting Started](getting-started.md) if setup issues persist
- ✅ Check [Common Tasks](common-tasks.md) for development patterns
- ✅ Review [Development Workflow](development-workflow.md) for Git and PR process

