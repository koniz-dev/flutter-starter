# Testing Summary

Quick reference guide for testing in the Flutter Starter project.

## Checklist before opening a PR

Run the same gates CI uses for Dart code (no Android/iOS/Web builds):

```bash
./scripts/dev/audit_template.sh
```

Or step by step:

```bash
./scripts/dev/format_dart.sh --check   # or: dart format --set-exit-if-changed lib test integration_test tool bricks
flutter analyze
flutter test
```

Optional (slower, matches coverage job): `flutter test --coverage --timeout=5m`. See [CONTRIBUTING.md](../../../CONTRIBUTING.md) for full contribution flow.

## Quick Start

### Run Tests
```bash
flutter test
```

### Generate Coverage
```bash
./scripts/test/test_coverage.sh --html
```

### E2E Testing (Patrol)
Ensure you have `patrol_cli` installed:
```bash
dart pub global activate patrol_cli
./scripts/test/run_e2e_tests.sh
```

### Analyze Coverage
```bash
./scripts/test/calculate_layer_coverage.sh
```

## Coverage Targets

| Layer | Target |
|-------|--------|
| Domain | 100% |
| Data | 90%+ |
| Core | 80%+ |
| Presentation | 80%+ |
| **Overall** | **80%+** |

## Test Structure

```
test/
├── helpers/          # Test utilities
├── core/            # Core layer tests
├── features/        # Feature layer tests
├── shared/          # Shared components
├── integration/     # Standard integration tests
└── integration_test/# E2E Patrol tests (e.g. auth_flow_test.dart)
```

## Key Files

- **Test Helpers:** `test/helpers/test_helpers.dart`
- **Test Fixtures:** `test/helpers/test_fixtures.dart`
- **Coverage Script:** `scripts/test/test_coverage.sh`
- **Analysis Script:** `scripts/test/calculate_layer_coverage.sh`

## CI/CD

- ✅ **Quality gate** on every push/PR to `main` ([`.github/workflows/ci.yml`](../../../.github/workflows/ci.yml)): format → analyze → unit tests on **one** runner (keeps GitHub Actions minutes low; branch protection can require **Quality gate**).
- ✅ Coverage thresholds (overall ≥80%, domain 100%, data ≥90%, presentation/core ≥80%) run in [`.github/workflows/coverage.yml`](../../../.github/workflows/coverage.yml) (manual **Run workflow** and weekly schedule), not on every PR.
- ✅ Codecov upload and optional PR comments live in that coverage workflow when you enable triggers that include pull requests.

### E2E on GitHub Actions (manual only)

Patrol E2E **does not block PRs**. To run on CI: open **Actions → [E2E Android (Patrol)](../../../.github/workflows/e2e-android.yml) → Run workflow**. Requires a working backend if the login flow calls your API. Integration tests use stable `ValueKey`s from `lib/core/constants/ui_keys.dart`.

## Documentation

- 📖 [Testing Guide](guide.md) - Comprehensive testing guide
- 📊 [Coverage Guide](test-coverage.md) - Coverage measurement and improvement
- 📝 [Test README](../../../test/README.md) - Test directory documentation
- 📂 [Repository layout (non-platform)](../onboarding/repository-layout.md) - Where tests and tools live in the tree

## Common Commands

```bash
# Format Dart (same scope as CI — avoids formatting `build/`)
./scripts/dev/format_dart.sh

# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Generate HTML report
./scripts/test/test_coverage.sh --html --open

# Analyze by layer
./scripts/test/calculate_layer_coverage.sh

# Run specific test
flutter test test/features/auth/domain/usecases/login_usecase_test.dart
```

## Best Practices

1. ✅ Use AAA pattern (Arrange, Act, Assert)
2. ✅ Mock all dependencies
3. ✅ Test edge cases
4. ✅ Keep tests fast (<100ms)
5. ✅ Use descriptive test names
6. ✅ Test error scenarios

## Resources

- [Flutter Testing Docs](https://docs.flutter.dev/testing)
- [Mocktail Documentation](https://pub.dev/packages/mocktail)
- [Riverpod Testing](https://riverpod.dev/docs/concepts/testing)


