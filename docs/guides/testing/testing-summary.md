# Testing Summary

Quick reference guide for testing in the Flutter Starter project.

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
| Core | 90%+ |
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

- ✅ Tests run on every push/PR
- ✅ Coverage enforced (80% minimum)
- ✅ Reports uploaded to Codecov
- ✅ PR comments with coverage summary

## Documentation

- 📖 [Testing Guide](guide.md) - Comprehensive testing guide
- 📊 [Coverage Guide](test-coverage.md) - Coverage measurement and improvement
- 📝 [Test README](../../test/README.md) - Test directory documentation

## Common Commands

```bash
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


