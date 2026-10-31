# Test Coverage Guide

This guide explains how test coverage is measured, enforced, and improved in the Flutter Starter project.

## Overview

Test coverage measures how much of the codebase is executed during tests. Two gates enforce it: every pull request's **Quality gate** checks total line coverage against `COVERAGE_MIN_TOTAL` in `ci.yml`, and the manual and weekly `coverage.yml` checks a total and a floor per layer (see [Coverage Enforcement](#coverage-enforcement)).

## Coverage Goals

### Layer-Specific Targets

| Layer | Target | Rationale |
|-------|--------|-----------|
| **Domain** | 100% | Business logic must be fully tested |
| **Data** | 90%+ | Data transformations and error handling are critical |
| **Core** | 80%+ | Checked by `coverage.yml` only; no pull-request gate checks a layer |
| **Presentation** | 80%+ | UI logic should be well-tested |
| **Shared** | 80%+ | A goal only: no gate checks `lib/shared/` on its own |

Domain, data, presentation and core are the `COVERAGE_MIN_*` values in
`coverage.yml`.

### Overall Target

The per-PR floor is `COVERAGE_MIN_TOTAL` in `ci.yml`, which starts a little
below what this starter measures. `coverage.yml` checks its own, lower total.

## Measuring Coverage

### Local Coverage

1. **Run tests with coverage:**
   ```bash
   dart run tool/coverage_helper.dart
   flutter test --coverage
   rm test/coverage_helper_test.dart
   ```

   `flutter test --coverage` records only the libraries some test loads, so a
   file no test imports would be missing from `lcov.info` and leave the total
   untouched. `tool/coverage_helper.dart` writes a git-ignored
   `test/coverage_helper_test.dart` that imports every library under `lib/`,
   so untested files count with zero hits. `test_coverage.sh` (without
   `--no-test`), the Quality gate and `coverage.yml` all run it first;
   `test_coverage.sh` removes the file again when it exits. Remove it yourself
   after a manual run, as above: it is git-ignored, so a copy left behind goes
   unnoticed until a rename under `lib/` makes its imports stale and breaks
   `flutter analyze` and `flutter test`.

2. **Generate HTML report:**
   ```bash
   ./scripts/test/test_coverage.sh --html
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
./scripts/test/test_coverage.sh

# Generate HTML report
./scripts/test/test_coverage.sh --html

# Open HTML report automatically
./scripts/test/test_coverage.sh --html --open

# Set minimum threshold
./scripts/test/test_coverage.sh --min=85

# Exclude paths from coverage (repeatable; drops every file whose path contains it)
./scripts/test/test_coverage.sh --exclude=lib/generated

# Per-layer breakdown and the files below 60%, without re-running the tests
./scripts/test/test_coverage.sh --no-test --analyze
```

Every figure is computed from `coverage/lcov.filtered.info`, a copy of
`coverage/lcov.info` with the files `coverage.yml` removes before it gates
(`*.g.dart`, `*.freezed.dart`, `*.config.dart`, `generated/`, `l10n/`,
`main.dart`, tests) plus any `--exclude` paths. The per-layer lines come from
`calculate_layer_coverage.sh --pattern=<regex>`, the same counter the CI gate
uses, so the layer percentages match CI's exactly. The overall percentage
counts executable lines the same way; CI's overall figure comes from
`lcov --summary` and can differ from it in the first decimal.

`scripts/test/test_coverage.ps1` (Windows) runs `tool/coverage_helper.dart`
and `flutter test --coverage`, fails when a test fails, and prints how to
render the HTML report. It does not support `--html`,
`--min`, `--exclude`, `--analyze` or `--no-test`; use the bash script under
Git Bash or WSL for those.

#### calculate_layer_coverage.sh

Reports the percentage of executable lines covered, per architectural layer:

```bash
./scripts/test/calculate_layer_coverage.sh                       # human summary
./scripts/test/calculate_layer_coverage.sh --github-output       # key=value only
```

```
Coverage by layer (percentage of executable lines covered):
  Domain:       100.0%
  Data:         96.2%
  Presentation: 93.5%
  Core:         85.2%
```

Four layers only — `domain`, `data`, `presentation` and `core`. It does **not**
list individual low-coverage files, and there is no `shared` layer figure; this
description previously claimed both. `--github-output` exists so
[`coverage.yml`](../../../.github/workflows/coverage.yml) can append the values
straight to `$GITHUB_OUTPUT` without the human text becoming step-output keys.

## CI/CD Coverage

### GitHub Actions

Two workflows measure coverage, from the same files:

- **`ci.yml`, every push and pull request.** The **Quality gate** runs
  `flutter test --coverage`, then its **Enforce minimum coverage** step runs
  `scripts/test/test_coverage.sh --no-test --min="$COVERAGE_MIN_TOTAL"`. Total
  line coverage below `COVERAGE_MIN_TOTAL` fails the PR. It checks the total
  only and needs no `lcov` install. It is not free: collecting coverage makes
  `flutter test` roughly 60% slower, which on this starter's suite adds about
  two minutes to the job (the threshold check itself takes under a second).
  To trade the gate back for speed, drop `--coverage` from the **Run tests**
  step and delete **Enforce minimum coverage**.
- **[`coverage.yml`](../../../.github/workflows/coverage.yml), manual plus
  weekly.** Its triggers are `workflow_dispatch` and a `schedule` (Mondays,
  03:00 UTC); the `push` / `pull_request` triggers are commented out, waiting
  for you to pick your branch names. A run is calculated over the whole
  repository, enforced against the per-layer targets in its **Enforce coverage
  thresholds** step, and uploaded to Codecov.

Both drop the same files before counting: `coverage.yml` with `lcov --remove`,
`test_coverage.sh` with the equivalent `awk` filter.
`test/tooling/ci_coverage_gate_test.dart` fails if the two lists drift.

### Codecov Integration

`coverage.yml` uploads with its **Upload to Codecov (Public)** step, which
passes no token: a public repository needs only the repository added at
https://codecov.io.

For a private repository, add `CODECOV_TOKEN` to the repository's Actions
secrets, then in `coverage.yml` comment out **Upload to Codecov (Public)** and
uncomment the **Upload to Codecov (Private)** block above it, which passes
the token.

Coverage reports are available at:
```
https://codecov.io/gh/[your-username]/[your-repo]
```

### PR Comments

`coverage.yml` posts no PR comment. Its results go to the run's job summary
and, if configured, to Codecov. Codecov can comment on pull requests itself
once its GitHub app is installed.

## Coverage Enforcement

### Minimum Threshold

The **Coverage Analysis** workflow enforces an **80% minimum** overall, plus
per-layer floors (domain 100%, data 90%, presentation 80%, core 80%) in its
**Enforce coverage thresholds** step of
[`coverage.yml`](../../../.github/workflows/coverage.yml), which reads them
from the workflow's `env:` block (`COVERAGE_MIN_TOTAL`, `COVERAGE_MIN_DOMAIN`,
`COVERAGE_MIN_DATA`, `COVERAGE_MIN_PRESENTATION`, `COVERAGE_MIN_CORE`). If coverage
drops below any of them, that workflow run fails.

Because that workflow is manual plus weekly, a per-layer target it misses does
**not** block a pull request. What does block one is the **Quality gate**'s
total floor, `COVERAGE_MIN_TOTAL` in
[`ci.yml`](../../../.github/workflows/ci.yml). It starts a little below what
this starter measures with and without its sample features, so a fresh project
is green; raise it as your suite grows.

### Increasing Threshold

To increase the minimum threshold:

1. **Update the per-PR floor** (`.github/workflows/ci.yml`), step **Enforce minimum coverage** — raise `COVERAGE_MIN_TOTAL`.

2. **Update coverage workflow** (`.github/workflows/coverage.yml`) — change the `COVERAGE_MIN_*` values in its `env:` block (e.g. `COVERAGE_MIN_TOTAL: 80`, `COVERAGE_MIN_DOMAIN: 100`); the **Enforce coverage thresholds** step reads them.

3. **Update coverage script** (`scripts/test/test_coverage.sh`):
   ```bash
   MIN_COVERAGE=85  # Change default
   ```

4. **Update documentation** (this file)

## Improving Coverage

### Identifying Gaps

1. **Run coverage analysis:**
   ```bash
   ./scripts/test/calculate_layer_coverage.sh
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
   - Follow [Testing Guide](guide.md)
   - Use AAA pattern (Arrange, Act, Assert)
   - Mock dependencies
   - Test edge cases

3. **Verify coverage:**
   ```bash
   ./scripts/test/test_coverage.sh
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

- Check coverage before merging PRs
- Set up coverage alerts
- Review coverage trends
- Fix coverage regressions

## Files That Are Not Counted

Both gates drop generated code (`*.g.dart`, `*.freezed.dart`, `*.config.dart`,
`generated/`), the generated localizations under `l10n/`, `main.dart` and test
code before counting; the list is `lcov --remove` in `coverage.yml` and the
same filter in `test_coverage.sh`.
Every other file under `lib/` counts, at the figure it measures: run
`./scripts/test/test_coverage.sh --analyze` to see the files below 60%.

## Troubleshooting

### Coverage Not Updating

**Problem:** Coverage percentage not changing after adding tests

**Solutions:**
- Ensure tests are actually running
- Check that assertions are passing
- Verify code path is being executed
- Clear coverage cache: `rm -rf coverage/`

### Coverage Too Low

**Problem:** Coverage below a `COVERAGE_MIN_*` floor

**Solutions:**
1. Identify gaps: `./scripts/test/calculate_layer_coverage.sh`
2. Add tests for uncovered code
3. Focus on high-impact areas first
4. Set incremental goals (e.g., 75% → 80% → 85%)

### CI Failing on Coverage

**Problem:** CI fails due to low coverage

**Solutions:**
- Read the failing step's output in the run log
- Reproduce it locally: `./scripts/test/test_coverage.sh --analyze`
- Add missing tests
- Temporarily lower threshold if needed (with justification)

## Coverage Tools

### Flutter Test

Built-in coverage. On its own it counts only the libraries some test loads;
see [Local Coverage](#local-coverage) for the helper CI runs first.
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
- [Testing Guide](guide.md)


