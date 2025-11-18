# Testing Guide

This guide covers testing practices, patterns, and best practices for the Flutter Starter project following Clean Architecture principles.

## Table of Contents

1. [Overview](#overview)
2. [Testing Strategy](#testing-strategy)
3. [Test Structure](#test-structure)
4. [Writing Tests](#writing-tests)
5. [Mocking with Riverpod](#mocking-with-riverpod)
6. [Test Fixtures](#test-fixtures)
7. [Coverage Goals](#coverage-goals)
8. [Running Tests](#running-tests)
9. [CI/CD Integration](#cicd-integration)

## Overview

This project follows Clean Architecture, which makes testing easier by:
- **Separation of Concerns**: Each layer can be tested independently
- **Dependency Inversion**: Dependencies are injected, making mocking straightforward
- **Framework Independence**: Business logic is independent of Flutter/Dart frameworks

## Testing Strategy

### Test Pyramid

```
        /\
       /  \      E2E Tests (Few)
      /____\     
     /      \    Integration Tests (Some)
    /________\   
   /          \  Unit Tests (Many)
  /____________\
```

### Test Types

1. **Unit Tests** (70% of tests)
   - Test individual components in isolation
   - Fast execution (<100ms each)
   - Mock all dependencies
   - Examples: Use cases, utilities, mappers

2. **Widget Tests** (20% of tests)
   - Test UI components
   - Test user interactions
   - Test state management
   - Examples: Screens, widgets, providers

3. **Integration Tests** (10% of tests)
   - Test complete flows
   - Test multiple components working together
   - Test error handling scenarios
   - Examples: Auth flow, token refresh, error recovery

## Test Structure

Tests mirror the source code structure:

```
test/
├── helpers/                    # Test utilities
│   ├── test_helpers.dart      # Common test helpers
│   ├── test_fixtures.dart     # Test data factories
│   └── pump_app.dart          # Widget test helpers
├── core/                       # Core layer tests
│   ├── config/
│   ├── network/
│   ├── storage/
│   ├── utils/
│   └── performance/
├── features/                   # Feature layer tests
│   └── auth/
│       ├── data/
│       ├── domain/
│       └── presentation/
├── shared/                     # Shared components tests
└── integration/                # Integration tests
    └── auth/
```

## Writing Tests

### AAA Pattern

Follow the **Arrange-Act-Assert** pattern:

```dart
test('should return User when login succeeds', () async {
  // Arrange
  const user = User(id: '1', email: 'test@example.com', name: 'Test');
  when(() => mockRepository.login(any(), any()))
      .thenAnswer((_) async => const Success(user));

  // Act
  final result = await loginUseCase('test@example.com', 'password');

  // Assert
  expect(result.isSuccess, isTrue);
  expect(result.dataOrNull, user);
  verify(() => mockRepository.login('test@example.com', 'password')).called(1);
});
```

### Test Naming Convention

Use descriptive test names that explain what is being tested:

```dart
// Good
test('should return User when login succeeds', () {});
test('should return AuthFailure when credentials are invalid', () {});
test('should cache user and token after successful login', () {});

// Bad
test('login test', () {});
test('test1', () {});
test('works', () {});
```

### Testing Use Cases

Use cases are the core business logic and should have **100% coverage**:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_starter/features/auth/domain/usecases/login_usecase.dart';
import 'package:flutter_starter/features/auth/domain/repositories/auth_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  group('LoginUseCase', () {
    late LoginUseCase loginUseCase;
    late MockAuthRepository mockRepository;

    setUp(() {
      mockRepository = MockAuthRepository();
      loginUseCase = LoginUseCase(mockRepository);
    });

    test('should return User when login succeeds', () async {
      // Arrange
      const user = User(id: '1', email: 'test@example.com', name: 'Test');
      when(() => mockRepository.login(any(), any()))
          .thenAnswer((_) async => const Success(user));

      // Act
      final result = await loginUseCase('test@example.com', 'password');

      // Assert
      expectResultSuccess(result, user);
      verify(() => mockRepository.login('test@example.com', 'password')).called(1);
    });

    test('should return failure when login fails', () async {
      // Arrange
      const failure = AuthFailure('Invalid credentials');
      when(() => mockRepository.login(any(), any()))
          .thenAnswer((_) async => const ResultFailure(failure));

      // Act
      final result = await loginUseCase('test@example.com', 'wrongpassword');

      // Assert
      expectResultFailure(result, failure);
      verify(() => mockRepository.login('test@example.com', 'wrongpassword')).called(1);
    });
  });
}
```

### Testing Repositories

Test repository implementations with mocked data sources:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_starter/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flutter_starter/features/auth/data/datasources/auth_local_datasource.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}
class MockAuthLocalDataSource extends Mock implements AuthLocalDataSource {}

void main() {
  group('AuthRepositoryImpl', () {
    late AuthRepositoryImpl repository;
    late MockAuthRemoteDataSource mockRemoteDataSource;
    late MockAuthLocalDataSource mockLocalDataSource;

    setUp(() {
      mockRemoteDataSource = MockAuthRemoteDataSource();
      mockLocalDataSource = MockAuthLocalDataSource();
      repository = AuthRepositoryImpl(
        remoteDataSource: mockRemoteDataSource,
        localDataSource: mockLocalDataSource,
      );
    });

    test('should return User and cache data when login succeeds', () async {
      // Arrange
      const authResponse = AuthResponseModel(
        user: UserModel(id: '1', email: 'test@example.com', name: 'Test'),
        token: 'access_token',
        refreshToken: 'refresh_token',
      );
      when(() => mockRemoteDataSource.login(any(), any()))
          .thenAnswer((_) async => authResponse);
      when(() => mockLocalDataSource.cacheUser(any()))
          .thenAnswer((_) async => {});
      when(() => mockLocalDataSource.cacheToken(any()))
          .thenAnswer((_) async => {});

      // Act
      final result = await repository.login('test@example.com', 'password');

      // Assert
      expect(result.isSuccess, isTrue);
      verify(() => mockRemoteDataSource.login('test@example.com', 'password')).called(1);
      verify(() => mockLocalDataSource.cacheUser(any())).called(1);
      verify(() => mockLocalDataSource.cacheToken('access_token')).called(1);
    });
  });
}
```

### Testing Providers (Riverpod)

Test Riverpod providers with provider overrides:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/features/auth/domain/usecases/login_usecase.dart';

class MockLoginUseCase extends Mock implements LoginUseCase {}

void main() {
  group('AuthProvider', () {
    late MockLoginUseCase mockLoginUseCase;

    setUp(() {
      mockLoginUseCase = MockLoginUseCase();
    });

    test('should emit loading then success when login succeeds', () async {
      // Arrange
      const user = User(id: '1', email: 'test@example.com', name: 'Test');
      when(() => mockLoginUseCase(any(), any()))
          .thenAnswer((_) async => const Success(user));

      // Act & Assert
      final container = ProviderContainer(
        overrides: [
          loginUseCaseProvider.overrideWithValue(mockLoginUseCase),
        ],
      );

      final notifier = container.read(authProvider.notifier);
      final result = await notifier.login('test@example.com', 'password');

      expect(result.isSuccess, isTrue);
      container.dispose();
    });
  });
}
```

### Testing Widgets

Test widgets with Riverpod providers:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_starter/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_starter/features/auth/domain/usecases/login_usecase.dart';
import 'package:flutter_starter/test/helpers/pump_app.dart';

class MockLoginUseCase extends Mock implements LoginUseCase {}

void main() {
  group('LoginScreen', () {
    late MockLoginUseCase mockLoginUseCase;

    setUp(() {
      mockLoginUseCase = MockLoginUseCase();
    });

    testWidgets('should display email and password fields', (tester) async {
      // Arrange & Act
      await pumpApp(
        tester,
        const LoginScreen(),
        overrides: [
          loginUseCaseProvider.overrideWithValue(mockLoginUseCase),
        ],
      );

      // Assert
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('should call login when form is submitted', (tester) async {
      // Arrange
      const user = User(id: '1', email: 'test@example.com', name: 'Test');
      when(() => mockLoginUseCase(any(), any()))
          .thenAnswer((_) async => const Success(user));

      await pumpApp(
        tester,
        const LoginScreen(),
        overrides: [
          loginUseCaseProvider.overrideWithValue(mockLoginUseCase),
        ],
      );

      // Act
      await tester.enterText(find.byType(TextFormField).first, 'test@example.com');
      await tester.enterText(find.byType(TextFormField).last, 'password');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Assert
      verify(() => mockLoginUseCase('test@example.com', 'password')).called(1);
    });
  });
}
```

## Mocking with Riverpod

### Creating Mocks

Use `mocktail` for creating mocks (no code generation required):

```dart
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
class MockLoginUseCase extends Mock implements LoginUseCase {}
```

### Overriding Providers

Override providers in tests:

```dart
final container = ProviderContainer(
  overrides: [
    loginUseCaseProvider.overrideWithValue(mockLoginUseCase),
    authRepositoryProvider.overrideWithValue(mockRepository),
  ],
);
```

### Using Overrides in Widget Tests

```dart
await pumpApp(
  tester,
  const LoginScreen(),
  overrides: [
    loginUseCaseProvider.overrideWithValue(mockLoginUseCase),
  ],
);
```

## Test Fixtures

Use test fixtures for creating test data:

```dart
import 'package:flutter_starter/test/helpers/test_fixtures.dart';

// Create test entities
final user = createUser(
  id: '1',
  email: 'test@example.com',
  name: 'Test User',
);

// Create test models
final userModel = createUserModel(
  id: '1',
  email: 'test@example.com',
);

// Create test failures
final failure = createAuthFailure(message: 'Invalid credentials');
```

See `test/helpers/test_fixtures.dart` for all available fixtures.

## Coverage Goals

### Layer-Specific Goals

| Layer | Target | Priority |
|-------|--------|----------|
| **Domain** | 100% | Critical |
| **Data** | 90%+ | High |
| **Core** | 90%+ | High |
| **Presentation** | 80%+ | Medium |
| **Shared** | 80%+ | Medium |

### Overall Target

**Minimum: 80%** overall coverage

### Critical Components (100% Required)

- All use cases
- Error mappers
- Configuration loaders
- Critical utilities

## Running Tests

### Run All Tests

```bash
flutter test
```

### Run Tests with Coverage

```bash
flutter test --coverage
```

### Generate HTML Coverage Report

```bash
./scripts/test_coverage.sh --html
```

### Analyze Coverage by Layer

```bash
./scripts/analyze_coverage.sh
```

### Run Specific Test File

```bash
flutter test test/features/auth/domain/usecases/login_usecase_test.dart
```

### Run Tests Matching Pattern

```bash
flutter test --name "login"
```

## CI/CD Integration

### GitHub Actions

Tests run automatically on:
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`

### Coverage Enforcement

- Minimum coverage threshold: **80%**
- Coverage reports uploaded to Codecov
- PR comments with coverage summary
- Coverage trend tracking

### Viewing Coverage

1. **Local**: Run `./scripts/test_coverage.sh --html --open`
2. **CI/CD**: Check workflow artifacts
3. **Codecov**: https://codecov.io/gh/[your-repo]

## Best Practices

### 1. Test Independence

Each test should be independent and not rely on other tests:

```dart
// Good
setUp(() {
  mockRepository = MockAuthRepository();
  loginUseCase = LoginUseCase(mockRepository);
});

// Bad - relies on previous test state
test('test 1', () {
  // modifies global state
});

test('test 2', () {
  // depends on test 1's modifications
});
```

### 2. Test Edge Cases

Always test edge cases:

- Empty inputs
- Null values
- Invalid data
- Network errors
- Timeout scenarios
- Boundary conditions

### 3. Use Descriptive Assertions

```dart
// Good
expect(result.isSuccess, isTrue, reason: 'Login should succeed with valid credentials');
expect(user.email, 'test@example.com');

// Bad
expect(result.isSuccess, isTrue);
```

### 4. Keep Tests Fast

- Mock external dependencies
- Avoid real network calls
- Avoid real file I/O
- Use in-memory storage for tests

### 5. One Assertion Per Test (When Possible)

```dart
// Good - focused test
test('should return User with correct id', () {
  expect(user.id, '1');
});

// Less ideal - multiple concerns
test('should return correct User', () {
  expect(user.id, '1');
  expect(user.email, 'test@example.com');
  expect(user.name, 'Test');
});
```

### 6. Test Error Scenarios

Always test error handling:

```dart
test('should return NetworkFailure when network error occurs', () async {
  when(() => mockRepository.login(any(), any()))
      .thenAnswer((_) async => const ResultFailure(NetworkFailure('No internet')));

  final result = await loginUseCase('test@example.com', 'password');

  expectResultFailureType(result, NetworkFailure);
});
```

## Common Patterns

### Testing Result Pattern

```dart
// Using test helpers
expectResultSuccess(result, expectedUser);
expectResultFailure(result, expectedFailure);
expectResultFailureType(result, NetworkFailure);
```

### Testing Async Operations

```dart
test('should handle async operation', () async {
  // Use async/await
  final result = await someAsyncOperation();
  expect(result, isNotNull);
});
```

### Testing Widget Interactions

```dart
testWidgets('should handle user input', (tester) async {
  await pumpApp(tester, const MyWidget());
  
  // Enter text
  await tester.enterText(find.byType(TextFormField), 'input');
  
  // Tap button
  await tester.tap(find.byType(ElevatedButton));
  
  // Wait for async operations
  await tester.pumpAndSettle();
  
  // Assert
  expect(find.text('Expected Result'), findsOneWidget);
});
```

## Troubleshooting

### Tests Failing Due to Provider Not Found

**Problem**: `ProviderNotFoundException`

**Solution**: Ensure all required providers are overridden:

```dart
await pumpApp(
  tester,
  const MyWidget(),
  overrides: [
    requiredProvider.overrideWithValue(mockValue),
  ],
);
```

### Tests Timing Out

**Problem**: Tests taking too long or timing out

**Solution**:
- Check for real network calls (should be mocked)
- Check for infinite loops
- Use `tester.pumpAndSettle()` with timeout
- Mock async operations properly

### Coverage Not Increasing

**Problem**: Coverage percentage not increasing after adding tests

**Solution**:
- Ensure tests are actually executing the code
- Check that assertions are passing (failing tests may not count)
- Verify the code path is being hit
- Check coverage report for specific files

## Additional Resources

- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [Mocktail Documentation](https://pub.dev/packages/mocktail)
- [Riverpod Testing](https://riverpod.dev/docs/concepts/testing)
- [Clean Architecture Testing](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)

