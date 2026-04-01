# Test Suite Documentation

This directory contains the comprehensive test suite for the Flutter Starter project.

> 📖 **Testing docs:** [Testing summary](../../docs/guides/testing/testing-summary.md) · [Testing guide](../../docs/guides/testing/guide.md)

## Structure

```
test/
├── helpers/          # Test utilities and helpers
├── core/             # Core layer tests
├── features/         # Feature layer tests (auth, home, tasks, feature_flags, …)
├── shared/           # Shared widgets, theme, extensions
└── integration/      # In-repo integration tests (not Patrol — see integration_test/)
```

Patrol E2E lives in [`integration_test/`](../integration_test/README.md).

## Running Tests

### All Tests
```bash
flutter test
```

### With Coverage
```bash
flutter test --coverage
```

### Using Coverage Scripts
```bash
# Generate HTML report and check coverage
./scripts/test/test_coverage.sh --html

# Analyze coverage by layer
./scripts/test/calculate_layer_coverage.sh

# Open HTML report automatically
./scripts/test/test_coverage.sh --html --open
```

### Specific Test File
```bash
flutter test test/features/auth/domain/usecases/login_usecase_test.dart
```

### Generate Coverage Report
```bash
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## Test Helpers

### test_helpers.dart
Common test utilities:
- `createTestApp()` - Creates test MaterialApp with providers
- `expectResultSuccess()` - Asserts Result is Success
- `expectResultFailure()` - Asserts Result is Failure

### test_fixtures.dart
Reusable test data:
- `createUser()` - Creates test User entity
- `createUserModel()` - Creates test UserModel
- `createAuthResponse()` - Creates test AuthResponseModel
- `createServerException()` - Creates test exceptions
- `createServerFailure()` - Creates test failures

### mock_factories.dart
Mock object factories:
- `createMockAuthRepository()` - Creates configured mock
- `createMockApiClient()` - Creates configured mock
- All mock classes for testing

### pump_app.dart
Widget testing helpers:
- `pumpApp()` - Pumps widget with ProviderScope
- `pumpAppAndSettle()` - Pumps and waits for animations

## Coverage Goals

Aligned with [coverage workflow gates](../../.github/workflows/coverage.yml) (see [testing-summary](../../docs/guides/testing/testing-summary.md)):

- **Domain:** 100%
- **Data:** 90%+
- **Presentation:** 80%+
- **Core:** 80%+
- **Overall:** 80%+

## Test Types

### Unit Tests
- Use cases
- Repositories
- Data sources
- Utilities
- Mappers

### Widget Tests
- Screens
- Custom widgets
- Providers

### Integration Tests
- Complete flows
- Error handling
- Token refresh

## Best Practices

1. Use AAA pattern (Arrange, Act, Assert)
2. One assertion per test (when possible)
3. Use descriptive test names
4. Mock external dependencies
5. Test edge cases
6. Keep tests fast (<100ms each)


