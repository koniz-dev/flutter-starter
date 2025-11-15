# Test Suite Documentation

This directory contains the comprehensive test suite for the Flutter Starter project.

## Structure

```
test/
├── helpers/          # Test utilities and helpers
├── core/            # Core layer tests
├── features/        # Feature layer tests
├── shared/          # Shared components tests
└── integration/     # Integration tests
```

## Running Tests

### All Tests
```bash
flutter test
```

### With Coverage
```bash
flutter test --coverage
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

- **Core Layer:** 90%+
- **Domain Layer:** 100% (use cases)
- **Data Layer:** 90%+
- **Presentation Layer:** 80%+

**Overall Target:** >80%

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

