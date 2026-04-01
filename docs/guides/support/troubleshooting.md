# Troubleshooting

This guide covers common issues, solutions, and frequently asked questions.

## Quick diagnosis (30 seconds)

Run these commands first; they answer 80% of “why doesn’t it build/run/test?”:

```bash
flutter --version
flutter doctor -v
flutter pub get
dart analyze
flutter test --fail-fast
```

If you are stuck after that, check the sections below by symptom (build/codegen/config/routing/iOS/CI hooks).

## Common Issues

### 1. `dart format .` fails or errors under `build/`

**Problem:** On some machines, `dart format .` walks the `build/` tree and can error (e.g. broken plugin paths on Windows).

**Solutions:**
```bash
flutter clean   # optional but clears a bad build/ tree
./scripts/dev/format_dart.sh
# or explicitly:
dart format lib test integration_test tool bricks
```

CI and git hooks use the scoped paths above, not the whole repo root.

### 2. Code Generation / `build_runner` errors

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
- If you use Riverpod codegen, ensure `build.yaml`/annotations are consistent across packages (and you didn’t rename imports without regenerating)

**Common failure messages and fixes:**
- **`Conflicting outputs`**: always run with `--delete-conflicting-outputs` (or clean + re-run).
- **`Target of URI doesn't exist`**: file moved/renamed but generated code still imports old path → clean + build again.
- **Analyzer sees stale generated files**: restart IDE analysis server after regen.

### 3. Configuration Not Loading

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

### 4. Mason issues (bricks, versions, missing commands)

**Problem**: `mason`/`mason get`/`mason make ...` fails.

**Solutions:**
```bash
dart pub global activate mason_cli
mason --version
mason get
```

**Common causes:**
- Mason CLI not installed globally.
- Brick constraints not met (check `environment.mason` in `bricks/**/brick.yaml`).
- You renamed the repo/package and expected Mason to rewrite Markdown automatically (it doesn’t; docs may still show `flutter_starter` until you update them).

### 4. Provider Not Found Errors

**Problem**: `ProviderNotFoundException` when accessing providers.

**Solutions:**
1. Ensure widget is wrapped in `ProviderScope` or `UncontrolledProviderScope`
2. Check provider is defined in `lib/core/di/providers.dart`
3. Verify provider name is correct (case-sensitive)
4. Ensure provider is registered before use

**Extra tip (tests):**
- Prefer `ProviderContainer(overrides: [...])` + `container.read(...)` for unit tests.
- For routing tests, validate current location via `GoRouter.routeInformationProvider.value.uri.path` to avoid brittle widget-finder assertions.

### 5. Network/API Errors

**Problem**: API calls failing or timing out.

**Solutions:**
1. Check `BASE_URL` in configuration
2. Verify network connectivity
3. Check API timeout settings in `AppConfig`
4. Review interceptor logs (if HTTP logging enabled)
5. Verify authentication tokens are valid

### 6. Storage Errors

**Problem**: Storage operations failing.

**Solutions:**
1. Ensure `storageInitializationProvider` is awaited in `main()`
2. Check platform permissions (Android/iOS)
3. Verify storage keys are correct
4. For secure storage, check platform-specific setup

### 7. Test Failures

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

**If tests try to hit real network:**
- Widget tests must not depend on external URLs. Use `HttpOverrides` or mock the network image loading to make tests deterministic.

**If `git push` fails with “failed to push some refs” but the real reason is tests:**
- Your repo likely has a pre-push hook that runs `flutter test`. Scroll up in the terminal output: the first failing test is the root cause.

### 8. Import Errors

**Problem**: Cannot find imports or "file not found" errors.

**Solutions:**
1. Run `flutter pub get`
2. Run code generation: `flutter pub run build_runner build`
3. Restart IDE/analysis server
4. Check file paths are correct
5. Verify `analysis_options.yaml` settings

### 9. Hot Reload Not Working

**Problem**: Changes not reflected after hot reload.

**Solutions:**
1. Some changes require hot restart:
   - Configuration changes
   - Provider changes
   - Static variable changes
2. Use hot restart (`R` in terminal) instead
3. If still not working, do a full restart

### 10. GoRouter redirects / “stuck on login” / unexpected navigation

**Problem**: Navigation keeps redirecting (e.g. always to `/login`) or routes don’t match expected paths.

**Quick checks:**
1. Confirm route constants and registered routes match (see `lib/core/routing/app_routes.dart` and `lib/core/routing/routes_registry.dart`).
2. Check the auth state provider used by router redirect logic (typically `authNotifierProvider`).
3. In tests, use `MaterialApp.router(routerConfig: router)` and assert `router.routeInformationProvider.value.uri.path`.

### 11. iOS CocoaPods issues

**Problem**: iOS build fails with Pod / Xcode errors.

**Solutions:**
```bash
flutter clean
flutter pub get
cd ios
pod repo update
pod install
cd ..
```

If you changed iOS bundle id or signing, open `ios/Runner.xcworkspace` and verify Signing & Capabilities.

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
   - [API Documentation](../../api/README.md)
   - [Common Patterns](../../api/examples/common-patterns.md)
   - [Architecture Docs](../../architecture/README.md)

2. **Code Examples**:
   - Check existing features (e.g., `lib/features/auth/`)
   - Review test files for usage patterns
   - See [Examples](../../api/examples/)

3. **Team Resources**:
   - Ask in team chat/Slack
   - Create an issue in the repository
   - Request code review early for guidance

4. **External Resources**:
   - [Flutter Documentation](https://docs.flutter.dev/)
   - [Riverpod Documentation](https://riverpod.dev/)
   - [Dart Documentation](https://dart.dev/)

## Next Steps

- ✅ Review [Getting Started](../onboarding/getting-started.md) if setup issues persist
- ✅ Check [Common Tasks](../features/common-tasks.md) for development patterns
- ✅ Review [Customization Guide](../migration/customization-guide.md) for adaptation workflow


