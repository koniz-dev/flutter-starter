# Test Coverage Guide

This guide explains how test coverage is measured, enforced, and improved in the Flutter Starter project.

## Overview

Test coverage measures how much of the codebase is executed during tests. We aim for **80%+ overall coverage** with higher targets for critical layers.

## Coverage Goals

### Layer-Specific Targets

| Layer | Target | Rationale |
|-------|--------|-----------|
| **Domain** | 100% | Business logic must be fully tested |
| **Data** | 90%+ | Data transformations and error handling are critical |
| **Core** | 90%+ | Infrastructure code affects entire app |
| **Presentation** | 80%+ | UI logic should be well-tested |
| **Shared** | 80%+ | Shared utilities used across features |

### Overall Target

**Minimum: 80%** overall coverage

## Measuring Coverage

### Local Coverage

1. **Run tests with coverage:**
   ```bash
   flutter test --coverage
   ```

2. **Generate HTML report:**
   ```bash
   ./scripts/test_coverage.sh --html
   ```

3. **View report:**
   ```bash
   open coverage/html/index.html
   ```

### Coverage Scripts

#### test_coverage.sh

Main coverage script with options:

```bash
# Basic coverage check
./scripts/test_coverage.sh

# Generate HTML report
./scripts/test_coverage.sh --html

# Open HTML report automatically
./scripts/test_coverage.sh --html --open

# Set minimum threshold
./scripts/test_coverage.sh --min=85

# Exclude paths from coverage
./scripts/test_coverage.sh --exclude=lib/generated
```

#### analyze_coverage.sh

Analyzes coverage by layer:

```bash
./scripts/analyze_coverage.sh
```

Output shows:
- Coverage by layer (Domain, Data, Presentation, Core, Shared)
- Files with low coverage (< 60%)
- Coverage percentages per component

## CI/CD Coverage

### GitHub Actions

Coverage is automatically:
- ✅ Calculated on every push/PR
- ✅ Enforced with 80% minimum threshold
- ✅ Uploaded to Codecov
- ✅ Commented on PRs

### Codecov Integration

1. **Sign up:** https://codecov.io
2. **Add repository:** Connect your GitHub repo
3. **Get token:** Copy your Codecov token
4. **Add secret:** Add `CODECOV_TOKEN` to GitHub Secrets

Coverage reports are available at:
```
https://codecov.io/gh/[your-username]/[your-repo]
```

### PR Comments

Every PR automatically receives a coverage comment showing:
- Overall coverage percentage
- Coverage by layer
- Coverage trend (increase/decrease)
- Link to detailed report

## Coverage Enforcement

### Minimum Threshold

The CI pipeline enforces an **80% minimum coverage**. If coverage drops below this:
- ❌ CI fails
- 📊 Coverage report shows gaps
- 🔍 PR comment highlights issues

### Increasing Threshold

To increase the minimum threshold:

1. **Update CI workflow** (`.github/workflows/test.yml`):
   ```yaml
   MIN_COVERAGE=85  # Change from 80 to 85
   ```

2. **Update coverage script** (`scripts/test_coverage.sh`):
   ```bash
   MIN_COVERAGE=85  # Change default
   ```

3. **Update documentation** (this file)

## Improving Coverage

### Identifying Gaps

1. **Run coverage analysis:**
   ```bash
   ./scripts/analyze_coverage.sh
   ```

2. **View HTML report:**
   - Red lines = not covered
   - Yellow lines = partially covered
   - Green lines = fully covered

3. **Check Codecov dashboard:**
   - See coverage trends
   - Identify files with low coverage
   - Review coverage by layer

### Adding Tests for Uncovered Code

1. **Identify uncovered files:**
   ```bash
   # View coverage report
   open coverage/html/index.html
   ```

2. **Write tests:**
   - Follow [Testing Guide](testing.md)
   - Use AAA pattern (Arrange, Act, Assert)
   - Mock dependencies
   - Test edge cases

3. **Verify coverage:**
   ```bash
   flutter test --coverage
   ./scripts/test_coverage.sh
   ```

### Common Coverage Gaps

#### 1. Error Handling

**Problem:** Error paths not tested

**Solution:**
```dart
test('should handle network error', () async {
  when(() => mockRepository.getData())
      .thenThrow(NetworkException('No internet'));
  
  final result = await useCase();
  
  expect(result.isFailure, isTrue);
});
```

#### 2. Edge Cases

**Problem:** Boundary conditions not tested

**Solution:**
```dart
test('should handle empty list', () async {
  when(() => mockRepository.getItems())
      .thenAnswer((_) async => const Success([]));
  
  final result = await useCase();
  
  expect(result.dataOrNull, isEmpty);
});
```

#### 3. Null Safety

**Problem:** Null checks not tested

**Solution:**
```dart
test('should handle null value', () async {
  when(() => mockRepository.getUser())
      .thenAnswer((_) async => const Success(null));
  
  final result = await useCase();
  
  expect(result.dataOrNull, isNull);
});
```

#### 4. Configuration

**Problem:** Config loading not tested

**Solution:**
```dart
test('should load config from environment', () {
  // Test with different environment variables
  // Test with missing variables
  // Test with invalid values
});
```

## Coverage Metrics

### Understanding Coverage Types

1. **Line Coverage:** Percentage of lines executed
2. **Branch Coverage:** Percentage of branches taken
3. **Function Coverage:** Percentage of functions called

We primarily track **line coverage** as it's the most practical metric.

### Coverage Reports

#### LCOV Format

Coverage data is stored in `coverage/lcov.info` (LCOV format):
- `SF:` = Source file
- `DA:` = Line data (line number, execution count)
- `FN:` = Function name
- `FNDA:` = Function data

#### HTML Report

The HTML report shows:
- File-by-file coverage
- Line-by-line highlighting
- Coverage percentages
- Uncovered lines

## Best Practices

### 1. Test Critical Paths First

Focus on:
- Business logic (use cases)
- Error handling
- Data transformations
- Configuration loading

### 2. Don't Obsess Over 100%

Some code doesn't need full coverage:
- Generated code (`.g.dart`, `.freezed.dart`)
- Main entry points (simple delegation)
- Exception constructors (framework code)

### 3. Use Coverage to Guide Testing

Coverage reports help identify:
- What's missing
- What's partially tested
- What needs more edge cases

### 4. Maintain Coverage Over Time

- ✅ Check coverage before merging PRs
- ✅ Set up coverage alerts
- ✅ Review coverage trends
- ✅ Fix coverage regressions

## Troubleshooting

### Coverage Not Updating

**Problem:** Coverage percentage not changing after adding tests

**Solutions:**
- Ensure tests are actually running
- Check that assertions are passing
- Verify code path is being executed
- Clear coverage cache: `rm -rf coverage/`

### Coverage Too Low

**Problem:** Coverage below 80%

**Solutions:**
1. Identify gaps: `./scripts/analyze_coverage.sh`
2. Add tests for uncovered code
3. Focus on high-impact areas first
4. Set incremental goals (e.g., 75% → 80% → 85%)

### CI Failing on Coverage

**Problem:** CI fails due to low coverage

**Solutions:**
- Check PR comment for details
- Review coverage report in artifacts
- Add missing tests
- Temporarily lower threshold if needed (with justification)

## Coverage Tools

### Flutter Test

Built-in coverage:
```bash
flutter test --coverage
```

### LCOV

Generate HTML reports:
```bash
genhtml coverage/lcov.info -o coverage/html
```

### Codecov

Cloud coverage tracking:
- Automatic PR comments
- Coverage trends
- Historical data
- Badge generation

## Additional Resources

- [Flutter Testing](https://docs.flutter.dev/testing)
- [Codecov Documentation](https://docs.codecov.com)
- [LCOV Documentation](https://github.com/linux-test-project/lcov)
- [Testing Guide](testing.md)

