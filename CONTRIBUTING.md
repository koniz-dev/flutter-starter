# Contributing to Flutter Starter

First off, thank you for considering contributing to Flutter Starter! 🎉

This document provides guidelines and instructions for contributing to this project. Following these guidelines helps communicate that you respect the time of the developers managing and developing this open source project.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Suggesting Enhancements](#suggesting-enhancements)
  - [Pull Requests](#pull-requests)
- [Development Setup](#development-setup)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Commit Message Guidelines](#commit-message-guidelines)
- [Testing Guidelines](#testing-guidelines)
- [Documentation](#documentation)

---

## Code of Conduct

This project adheres to a Code of Conduct that all contributors are expected to follow. Please be respectful and considerate of others when contributing.

### Our Standards

- ✅ Be respectful and inclusive
- ✅ Welcome newcomers and help them learn
- ✅ Focus on constructive feedback
- ✅ Respect different viewpoints and experiences

---

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the issue list as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible:

#### Before Submitting a Bug Report

- **Check the documentation** - The issue might already be documented
- **Check existing issues** - The bug might have already been reported
- **Test with the latest version** - Make sure you're using the latest code

#### How to Report a Bug

1. **Use the bug report template** (if available on GitHub)
2. **Include the following information:**
   - Flutter version (`flutter --version`)
   - Dart version
   - Platform (Android/iOS/Web/Linux/macOS/Windows)
   - Steps to reproduce
   - Expected behavior
   - Actual behavior
   - Screenshots (if applicable)
   - Error messages or logs

#### Example Bug Report

```markdown
**Flutter Version:** 3.24.0
**Dart Version:** 3.4.0
**Platform:** Android

**Steps to Reproduce:**
1. Open the app
2. Navigate to Tasks screen
3. Try to create a new task
4. App crashes

**Expected Behavior:**
Task should be created successfully

**Actual Behavior:**
App crashes with error: [error message]

**Logs:**
[Paste relevant logs here]
```

---

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

1. **Clear and descriptive title**
2. **Detailed description** of the enhancement
3. **Use case** - Why is this enhancement useful?
4. **Possible implementation** (if you have ideas)
5. **Alternatives considered** (if any)

#### Example Enhancement Suggestion

```markdown
**Enhancement:** Add dark mode toggle in settings

**Description:**
Add a toggle switch in the settings screen to allow users to switch between light and dark themes.

**Use Case:**
Users prefer dark mode for better battery life and eye comfort, especially in low-light conditions.

**Possible Implementation:**
- Add a Switch widget in SettingsScreen
- Use ThemeModeProvider to toggle between light/dark/system
- Persist preference in SharedPreferences
```

---

### Pull Requests

Pull requests are the best way to propose changes to the codebase. We actively welcome your pull requests.

> Issues are the single source of truth for what gets worked on, in what order,
> and when it counts as done. Before picking something up, read
> [docs/issue-workflow.md](docs/issue-workflow.md) — it defines the label state
> machine, the acceptance-criteria requirement, and why commits link to issues
> rather than closing them.


1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Follow our coding standards
5. Write or update tests
6. Update documentation
7. Commit your changes (see [Commit Message Guidelines](#commit-message-guidelines))
8. Push to the branch (`git push origin feature/amazing-feature`)
9. Open a Pull Request

#### Pull Request Checklist

Before submitting a PR, make sure:

- [ ] Code follows the project's style guidelines
- [ ] All tests pass (`flutter test`)
- [ ] Code analysis passes (`flutter analyze`)
- [ ] Documentation is updated (if needed)
- [ ] Commit messages follow the guidelines
- [ ] PR description is clear and descriptive
- [ ] Related issues are referenced with `Refs owner/repo#N` (never `Closes`/`Fixes`/`Resolves`)

---

## Development Setup

### Prerequisites

- Flutter SDK **>=3.38.4**
- Dart SDK **>=3.10.3** (bundled with Flutter)
- Git
- IDE (VS Code, Android Studio, or IntelliJ IDEA)

Those are the floors the committed `pubspec.lock` resolves against (see its
`sdks:` block). `pubspec.yaml` declares the looser `environment: sdk: '^3.8.0'`
and no `flutter:` constraint at all, so an older SDK does not fail with a clear
message - it fails inside `flutter pub get` with a transitive solve error
naming a package such as `path_provider_foundation`. Trust the lockfile.

### Setup Steps

1. **Fork and clone the repository**
   ```bash
   git clone https://github.com/your-username/flutter_starter.git
   cd flutter_starter
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate code** (Freezed, JSON serialization)
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Set up environment configuration**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

5. **Run the app**
   ```bash
   flutter run
   ```

6. **Run tests**
   ```bash
   flutter test
   ```

---

## Development Workflow

### Branch Naming

Use the following naming convention:

```
<type>/<short-description>

Examples:
- feature/add-product-search
- fix/auth-token-refresh
- refactor/extract-common-widgets
- docs/update-onboarding-guide
- test/add-auth-integration-tests
```

**Types:**
- `feature/` - New features
- `fix/` - Bug fixes
- `refactor/` - Code refactoring
- `docs/` - Documentation changes
- `test/` - Test additions/changes
- `chore/` - Maintenance tasks

### Workflow Steps

1. **Create a feature branch** from `main`
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** and commit frequently

   Stage explicitly. Do **not** use `git add .`: `flutter pub get` rewrites
   `analysis_options.yaml` and writes `ios/Podfile`, `macos/Podfile` and four
   `*.xcconfig` files as a side effect, and `git add .` sweeps that tooling
   churn into your commit where a reviewer has to work out whether it was
   deliberate.

   ```bash
   git status                       # see exactly what changed
   git add lib/features/products    # name what you touched
   git commit -m "feat: add product listing screen"
   ```

   Revert the churn before committing if it appears:

   ```bash
   git checkout -- analysis_options.yaml ios/Flutter macos/Flutter
   ```

3. **Keep your branch up to date**
   ```bash
   git checkout main
   git pull origin main
   git checkout feature/your-feature-name
   git merge main  # or git rebase main
   ```

4. **Push your branch**
   ```bash
   git push origin feature/your-feature-name
   ```

5. **Create a Pull Request** on GitHub

### Pre-PR quality gate (non-platform)

Before opening a PR, run (same scope as CI for Dart — no platform builds):

```bash
./scripts/dev/audit_template.sh
```

This runs scoped `dart format --check`, `flutter analyze`, and `flutter test`. On Windows without Bash, run the commands in [docs/guides/testing/testing-summary.md](docs/guides/testing/testing-summary.md) manually.

If your change touches markdown, also run the docs checker - `ci.yml` skips
docs, so the **Docs check** workflow is what gates them:

```bash
dart run tool/check_docs.dart
```

It verifies every relative link and heading anchor under `docs/` resolves, and
that `docs/`, `CLAUDE.md` and `.claude/` stay emoji-free.

### GitHub branch protection (recommended)

On the default branch (for example `main`), you can require the **Quality gate** status before merge:

1. Repository **Settings** → **Rules** → **Rulesets** (or **Branches** → **Branch protection rules**, depending on your org).
2. Add a rule for `main` (or your default branch).
3. Enable **Require status checks to pass before merging**.
4. Add the check named **Quality gate** (the single job in `.github/workflows/ci.yml`: format, analyze, then unit tests on **one** runner to limit Actions minutes for forks).

If you later split CI into parallel jobs for speed, you can require each job or add an aggregate job again for one required check.

---

## Coding Standards

### Code Style

- Follow [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use `very_good_analysis` linting rules (already configured)
- Run `flutter analyze` before committing
- Format Dart sources (not the whole repo — skips `build/`): `./scripts/dev/format_dart.sh` or `dart format lib test integration_test tool examples`

### Architecture

- Follow **Clean Architecture** principles
- Separate concerns: Domain → Data → Presentation
- Use dependency injection (Riverpod)
- Keep business logic in domain layer
- Keep UI logic in presentation layer

### Code Organization

```
lib/
├── core/           # Infrastructure (config, network, storage, etc.)
├── features/       # Feature modules (Clean Architecture)
│   └── feature_name/
│       ├── data/
│       ├── domain/
│       └── presentation/
└── shared/         # Shared resources (widgets, theme, extensions)
```

### Naming Conventions

- **Files:** `snake_case.dart`
- **Classes:** `PascalCase`
- **Variables/Functions:** `camelCase`
- **Constants:** `lowerCamelCase` or `UPPER_SNAKE_CASE`
- **Private members:** `_leadingUnderscore`

### Best Practices

- ✅ Use `const` constructors when possible
- ✅ Prefer `final` over `var`
- ✅ Use null safety properly
- ✅ Add documentation comments for public APIs
- ✅ Keep functions small and focused
- ✅ Avoid deep nesting (max 3-4 levels)
- ✅ Use meaningful variable names
- ✅ Extract magic numbers to constants

---

## Commit Message Guidelines

We follow [Conventional Commits](https://www.conventionalcommits.org/) specification.

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation changes
- `style` - Code style changes (formatting, etc.)
- `refactor` - Code refactoring
- `test` - Test additions/changes
- `chore` - Maintenance tasks
- `perf` - Performance improvements
- `ci` - CI/CD changes
- `build` - Build system or external dependencies (e.g. Gradle, pods)
- `revert` - Reverts a previous commit

### Examples

```bash
feat(auth): add token refresh functionality

fix(network): handle connection timeout errors

docs(guides): update onboarding instructions

refactor(products): extract product card widget

test(auth): add login use case tests
```

### Guidelines

- Use present tense ("add" not "added")
- Keep subject line under 50 characters
- Capitalize first letter of subject
- No period at end of subject
- Reference issues in the footer as `Refs koniz-dev/flutter-starter#123`

> **Do not use `Closes`, `Fixes`, or `Resolves`.** GitHub auto-closes an issue
> when a commit carrying those keywords lands on the default branch. That closes
> it at *merge* time, before anyone has run its acceptance criteria — which
> removes the verification gate the workflow exists to enforce. Use the fully
> qualified `owner/repo#N` form so the reference survives being quoted elsewhere.
> See [docs/issue-workflow.md](docs/issue-workflow.md).

### Git hooks

Hooks are **not** installed by a clone. Install them once:

```bash
./scripts/dev/setup_git_hooks.sh      # or setup_git_hooks.ps1 on Windows
```

That copies `.githooks/*` into `.git/hooks/`: `pre-commit` runs the scoped
`dart format` check and `flutter analyze`, `commit-msg` enforces the format
above, and `pre-push` runs `flutter test`. Skip them for one command with
`git commit --no-verify` / `git push --no-verify` — which switches off *every*
hook, not just the one in your way.

**They are expected to work inside a `git worktree`.** `.git/hooks/` is shared
by every worktree of a repository, so installing once covers all of them, and
`pre-commit` and `pre-push` now scrub `GIT_DIR` and its siblings out of the
environment before calling `flutter` or `dart`. Without that, git's exported
`GIT_DIR` makes the Flutter SDK resolve its own version against *this*
repository instead of the SDK, which reported
`The current Flutter SDK version is 0.0.0-unknown` and rejected commits that
were clean when the same command was run by hand
([#140](https://github.com/koniz-dev/flutter-starter/issues/140)). If you ever
see a hook report an SDK version that is not the one `flutter --version` prints
outside the hook, that is the symptom, and it is a bug worth filing.

---

## Testing Guidelines

### Test Structure

Tests should mirror the source code structure:

```
test/
├── core/
├── features/
│   └── feature_name/
│       ├── data/
│       ├── domain/
│       └── presentation/
└── helpers/
```

### Test Types

1. **Unit Tests** - Test individual functions/classes
2. **Widget Tests** - Test UI components
3. **Integration Tests** - Test complete flows

### Writing Tests

- ✅ Write tests for new features
- ✅ Write tests for bug fixes
- ✅ Aim for high test coverage
- ✅ Use descriptive test names
- ✅ Follow AAA pattern (Arrange, Act, Assert)
- ✅ Mock external dependencies

### Example Test

This project uses **mocktail**, not mockito, and its own `Result` type
(`Success` / `ResultFailure`), not `Either` / `Right` - there is no `dartz` or
`fpdart` dependency. Two mocktail specifics that trip people up: matchers are
**called** (`any()`, not `any`), and the stubbed call is wrapped in a closure
(`when(() => ...)`).

```dart
import 'package:flutter_starter/core/errors/failures.dart';
import 'package:flutter_starter/core/utils/result.dart';
import 'package:flutter_starter/features/auth/domain/entities/user.dart';
import 'package:flutter_starter/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_starter/features/auth/domain/usecases/login_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  group('LoginUseCase', () {
    late MockAuthRepository mockRepository;
    late LoginUseCase useCase;

    setUp(() {
      mockRepository = MockAuthRepository();
      useCase = LoginUseCase(mockRepository);
    });

    test('returns Success when the repository succeeds', () async {
      // Arrange
      const user = User(id: '1', email: 'email@example.com', name: 'Ada');
      when(
        () => mockRepository.login(any(), any()),
      ).thenAnswer((_) async => const Success(user));

      // Act
      final result = await useCase('email@example.com', 'password');

      // Assert
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, user);
      verify(
        () => mockRepository.login('email@example.com', 'password'),
      ).called(1);
    });

    test('returns a failure when the repository fails', () async {
      // Arrange
      const failure = AuthFailure('Invalid credentials');
      when(
        () => mockRepository.login(any(), any()),
      ).thenAnswer((_) async => const ResultFailure<User>(failure));

      // Act
      final result = await useCase('email@example.com', 'wrong-password');

      // Assert
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, failure);
    });
  });
}
```

`any()` needs no setup for built-in types such as `String`. When you stub a
method that takes one of your own classes, register a fallback first:

```dart
setUpAll(() {
  registerFallbackValue(const User(id: '0', email: 'fallback@example.com'));
});
```

See `test/features/auth/domain/usecases/login_usecase_test.dart` for the
version that ships.

### Running Tests

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/features/auth/domain/usecases/login_test.dart
```

---

## Documentation

### Code Documentation

- Add documentation comments for public APIs
- Use `///` for documentation comments
- Document parameters, return values, and exceptions
- Include code examples when helpful

### Example

```dart
/// Authenticates a user with email and password.
///
/// Returns [Result<User>] containing either:
/// - [Success<User>] with authenticated user on success
/// - [ResultFailure] with error details on failure
///
/// Throws [Exception] if authentication service is unavailable.
///
/// Example:
/// ```dart
/// final result = await loginUseCase('email@example.com', 'password');
/// result.when(
///   success: (user) => print('Logged in: ${user.email}'),
///   failure: (error) => print('Error: $error'),
/// );
/// ```
Future<Result<User>> call(String email, String password) async {
  // Implementation
}
```

### Documentation Updates

When adding new features:

- ✅ Update README.md if needed
- ✅ Add/update API documentation
- ✅ Update guides if workflow changes
- ✅ Add examples if introducing new patterns

---

## Review Process

### What to Expect

1. **Automated Checks** - GitHub Actions runs **Quality gate** (format → analyze → tests on one Ubuntu runner) for branch protection
2. **Code Review** - Maintainers will review your code
3. **Feedback** - You may receive suggestions for improvements
4. **Iteration** - You may need to make changes based on feedback

### Responding to Feedback

- Be open to suggestions
- Ask questions if something is unclear
- Make requested changes promptly
- Update your PR when changes are made

---

## Getting Help

If you need help:

1. **Check the documentation** - `docs/` folder
2. **Search existing issues** - Someone might have asked the same question
3. **Open a discussion** - Use GitHub Discussions for questions
4. **Ask in PR comments** - If related to a specific PR

---

## Recognition

Contributors will be recognized in:

- README.md (Contributors section)
- Release notes (for significant contributions)
- Project documentation

---

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

## Thank You! 🙏

Thank you for taking the time to contribute to Flutter Starter! Your contributions make this project better for everyone.

---

**Questions?** Open an issue or start a discussion on GitHub.

