# Contributing

How changes get into this project: setting up a machine, branching, committing,
and the checks every pull request has to pass.

## Table of Contents

- [Development Setup](#development-setup)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Commit Message Guidelines](#commit-message-guidelines)
- [Testing Guidelines](#testing-guidelines)
- [Documentation](#documentation)
- [Review Process](#review-process)

---

## Development Setup

### Prerequisites

- Flutter SDK **>=3.47.0**
- Dart SDK **>=3.13.0** (bundled with Flutter)
- Git
- IDE (VS Code, Android Studio, or IntelliJ IDEA)

Those are the floors the committed `pubspec.lock` resolves against (see its
`sdks:` block), and `pubspec.yaml`'s `environment:` states the same ones, so an
older SDK fails `flutter pub get` with a message naming the SDK version it
needs. `test/tooling/sdk_floor_test.dart` fails if the two drift apart.

### Setup Steps

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd <project-directory>
   ```

2. **Install dependencies and the git hooks**
   ```bash
   flutter pub get
   ./scripts/dev/setup_git_hooks.sh
   ```

   Generated code (Freezed, json_serializable, Riverpod) is committed. Run
   `flutter pub run build_runner build --delete-conflicting-outputs` only after
   changing an annotated source.

3. **Point the app at your API** (optional; a debug build without `BASE_URL`
   uses the offline demo sign-in)
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

4. **Run the app**
   ```bash
   flutter run --dart-define-from-file=.env
   ```
   Plain `flutter run` ignores `.env` (it is not an asset) and runs on the
   built-in defaults.

5. **Run tests**
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

   Stage explicitly. Do **not** use `git add .`: it sweeps in anything else
   the working tree happens to hold, and a reviewer then has to work out
   whether it was deliberate.

   ```bash
   git status                       # see exactly what changed
   git add lib/features/products    # name what you touched
   git commit -m "feat: add product listing screen"
   ```

   `flutter pub get` leaves the tree clean on the current stable. If it
   changes `pubspec.lock`, `analysis_options.yaml` or an `*.xcconfig`, a new
   Flutter stable re-pinned or re-migrated something: that belongs in its own
   change on `main` (re-run `flutter pub get` and commit), not in your feature.

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

### Pull Request Checklist

Before asking for review, make sure:

- [ ] Code follows the project's style guidelines
- [ ] `./scripts/dev/audit_template.sh` passes (generated code, format, analyze, tests)
- [ ] Documentation is updated (if needed)
- [ ] Commit messages follow the guidelines
- [ ] The PR description says what changed and why, and links the issue it addresses

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

It verifies every relative link and heading anchor resolves without leaving the
repository - in `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md` and the markdown
under `docs/`, `test/`, `scripts/`, `tool/`, `bricks/`, `examples/`,
`integration_test/` and `fastlane/` - and
that `docs/`, `CLAUDE.md` and `.claude/` stay emoji-free.

### GitHub branch protection (recommended)

On the default branch (for example `main`), you can require the **Quality gate** status before merge:

1. Repository **Settings** → **Rules** → **Rulesets** (or **Branches** → **Branch protection rules**, depending on your org).
2. Add a rule for `main` (or your default branch).
3. Enable **Require status checks to pass before merging**.
4. Add the check named **Quality gate** (the single job in `.github/workflows/ci.yml`: format, analyze, then unit tests on **one** runner to limit Actions minutes).

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
- Keep the subject short enough to read in `git log --oneline`; there is no
  fixed limit, and the `commit-msg` hook checks only the format, not the length
- Start the subject in lowercase, as the examples above do
- No period at end of subject
  

### Git hooks

Hooks are **not** installed by a clone. Install them once:

```bash
./scripts/dev/setup_git_hooks.sh      # or setup_git_hooks.ps1 on Windows
```

That points this repository's `core.hooksPath` at `.githooks/`, so git runs
the tracked hooks directly - a later fix to a hook needs no reinstall, and a
global `core.hooksPath` (a husky-style setup) cannot silently bypass them; a
repository-local one that points elsewhere makes the script stop and say so.
`pre-commit` runs the scoped
`dart format` check and `flutter analyze` on what is staged - the content the
commit will hold, exported to a temporary directory - not on your working
copy, so a fix you have not staged does not count and an unstaged broken file
does not block the commit. `commit-msg` enforces the format
above, and `pre-push` runs `flutter test`. Skip them for one command with
`git commit --no-verify` / `git push --no-verify` — which switches off *every*
hook, not just the one in your way.

**They are expected to work inside a `git worktree`.** `core.hooksPath` lives
in the configuration every worktree of a repository shares, so installing once
covers all of them, and
`pre-commit` and `pre-push` now scrub `GIT_DIR` and its siblings out of the
environment before calling `flutter` or `dart`. Without that, git's exported
`GIT_DIR` makes the Flutter SDK resolve its own version against *this*
repository instead of the SDK, which reported
`The current Flutter SDK version is 0.0.0-unknown` and rejected commits that
were clean when the same command was run by hand.
If you ever
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
flutter test test/features/auth/domain/usecases/login_usecase_test.dart
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
///   failureCallback: (error) => print('Error: $error'),
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
2. **Code Review** - A teammate reviews your code
3. **Feedback** - You may receive suggestions for improvements
4. **Iteration** - You may need to make changes based on feedback

### Responding to Feedback

- Be open to suggestions
- Ask questions if something is unclear
- Make requested changes promptly
- Update your PR when changes are made

---

## License

Contributions are licensed under the project's license; see [LICENSE](LICENSE).
