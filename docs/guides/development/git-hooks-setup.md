# Git Hooks Setup

This guide explains how to set up Git hooks for Flutter projects, similar to Husky in Node.js projects.

## Overview

Git hooks allow you to run scripts automatically at certain points in the Git workflow (e.g., before commit, before push). This helps ensure code quality by running checks like:

- Code formatting (`dart format`)
- Linting (`flutter analyze`)
- Running tests
- Checking commit message format

## Options for Flutter/Dart

### Option 1: `git_hooks` Package (Recommended)

A Dart package that provides Git hooks management similar to Husky.

**Pros:**
- Pure Dart solution
- No external dependencies
- Easy to configure
- Works on all platforms

**Cons:**
- Less popular than Husky
- Smaller community

### Option 2: `husky` (Dart/Flutter version)

A Dart/Flutter port of the popular Husky tool.

**Pros:**
- Familiar API for developers coming from Node.js
- Well-documented
- Active maintenance

**Cons:**
- Requires Dart SDK to be available
- Less native to Flutter ecosystem

### Option 3: Manual Git Hooks

Set up Git hooks manually using shell scripts.

**Pros:**
- No dependencies
- Full control
- Works everywhere

**Cons:**
- More setup required
- Harder to maintain
- Platform-specific scripts needed

---

## Setup with `git_hooks` (Recommended)

### Step 1: Add Dependency

Add `git_hooks` to `pubspec.yaml`:

```yaml
dev_dependencies:
  git_hooks: ^0.0.2
```

### Step 2: Create Git Hooks Configuration

Create `tool/git_hooks.dart`:

```dart
import 'dart:io';

import 'package:git_hooks/git_hooks.dart';

void main(List<String> arguments) {
  GitHooks.call(arguments, {
    GitHooks.preCommit: () {
      print('Running pre-commit checks...');
      
      // Run dart format
      final formatResult = Process.runSync(
        'dart',
        ['format', '--set-exit-if-changed', '.'],
      );
      if (formatResult.exitCode != 0) {
        print('❌ Code formatting check failed!');
        print('Please run: dart format .');
        return false;
      }
      
      // Run flutter analyze
      final analyzeResult = Process.runSync(
        'flutter',
        ['analyze'],
      );
      if (analyzeResult.exitCode != 0) {
        print('❌ Code analysis failed!');
        return false;
      }
      
      print('✅ Pre-commit checks passed!');
      return true;
    },
    GitHooks.commitMsg: () {
      // Check commit message format (Conventional Commits)
      final commitMsg = File.fromUri(Uri.parse('.git/COMMIT_EDITMSG'))
          .readAsStringSync()
          .trim();
      
      final conventionalCommitPattern = RegExp(
        r'^(feat|fix|docs|style|refactor|test|chore|perf|ci)(\(.+\))?: .+',
      );
      
      if (!conventionalCommitPattern.hasMatch(commitMsg)) {
        print('❌ Commit message does not follow Conventional Commits format!');
        print('Format: <type>(<scope>): <subject>');
        print('Example: feat(auth): add login functionality');
        return false;
      }
      
      return true;
    },
    GitHooks.prePush: () {
      print('Running pre-push checks...');
      
      // Run tests
      final testResult = Process.runSync(
        'flutter',
        ['test'],
      );
      if (testResult.exitCode != 0) {
        print('❌ Tests failed!');
        return false;
      }
      
      print('✅ Pre-push checks passed!');
      return true;
    },
  });
}
```

### Step 3: Install Git Hooks

Run the installation command:

```bash
dart run tool/git_hooks.dart install
```

Or add it to your setup script:

```bash
# In setup.sh or similar
dart run tool/git_hooks.dart install
```

### Step 4: Test Git Hooks

Try making a commit with invalid format:

```bash
git commit -m "invalid commit message"
# Should fail with error message
```

Try making a commit with valid format:

```bash
git commit -m "feat: add new feature"
# Should pass and commit successfully
```

---

## Setup with Manual Git Hooks

### Step 1: Create Hook Scripts

Create `.githooks/pre-commit`:

```bash
#!/bin/bash

echo "Running pre-commit checks..."

# Run dart format
dart format --set-exit-if-changed .
if [ $? -ne 0 ]; then
  echo "❌ Code formatting check failed!"
  echo "Please run: dart format ."
  exit 1
fi

# Run flutter analyze
flutter analyze
if [ $? -ne 0 ]; then
  echo "❌ Code analysis failed!"
  exit 1
fi

echo "✅ Pre-commit checks passed!"
exit 0
```

Create `.githooks/commit-msg`:

```bash
#!/bin/bash

commit_msg=$(cat "$1")

# Check Conventional Commits format
if ! echo "$commit_msg" | grep -qE "^(feat|fix|docs|style|refactor|test|chore|perf|ci)(\(.+\))?: .+"; then
  echo "❌ Commit message does not follow Conventional Commits format!"
  echo "Format: <type>(<scope>): <subject>"
  echo "Example: feat(auth): add login functionality"
  exit 1
fi

exit 0
```

Create `.githooks/pre-push`:

```bash
#!/bin/bash

echo "Running pre-push checks..."

# Run tests
flutter test
if [ $? -ne 0 ]; then
  echo "❌ Tests failed!"
  exit 1
fi

echo "✅ Pre-push checks passed!"
exit 0
```

### Step 2: Make Scripts Executable

```bash
chmod +x .githooks/pre-commit
chmod +x .githooks/commit-msg
chmod +x .githooks/pre-push
```

### Step 3: Install Hooks

```bash
# Copy hooks to .git/hooks
cp .githooks/* .git/hooks/
chmod +x .git/hooks/*
```

Or use a setup script:

```bash
#!/bin/bash
# setup-git-hooks.sh

if [ -d ".git/hooks" ]; then
  cp .githooks/* .git/hooks/
  chmod +x .git/hooks/*
  echo "✅ Git hooks installed successfully!"
else
  echo "❌ .git/hooks directory not found. Are you in a Git repository?"
  exit 1
fi
```

### Step 4: Automate Installation

Add to `README.md` or setup instructions:

```bash
# Install Git hooks
./scripts/setup-git-hooks.sh
```

---

## Recommended Setup

For this Flutter Starter template, we recommend using **manual Git hooks** because:

1. **No dependencies** - Keeps `pubspec.yaml` clean
2. **Simple** - Easy to understand and modify
3. **Reliable** - Works on all platforms
4. **Flexible** - Easy to customize for your needs

### Quick Setup Script

Create `scripts/setup-git-hooks.sh`:

```bash
#!/bin/bash

set -e

echo "🔧 Setting up Git hooks..."

# Create .githooks directory if it doesn't exist
mkdir -p .githooks

# Create pre-commit hook
cat > .githooks/pre-commit << 'EOF'
#!/bin/bash

echo "Running pre-commit checks..."

# Check if Flutter is available
if ! command -v flutter &> /dev/null; then
  echo "⚠️  Flutter not found. Skipping checks."
  exit 0
fi

# Run dart format
echo "📝 Checking code formatting..."
dart format --set-exit-if-changed . || {
  echo "❌ Code formatting check failed!"
  echo "Please run: dart format ."
  exit 1
}

# Run flutter analyze
echo "🔍 Running code analysis..."
flutter analyze || {
  echo "❌ Code analysis failed!"
  exit 1
}

echo "✅ Pre-commit checks passed!"
exit 0
EOF

# Create commit-msg hook
cat > .githooks/commit-msg << 'EOF'
#!/bin/bash

commit_msg=$(cat "$1")

# Skip merge commits
if echo "$commit_msg" | grep -qE "^Merge "; then
  exit 0
fi

# Check Conventional Commits format
if ! echo "$commit_msg" | grep -qE "^(feat|fix|docs|style|refactor|test|chore|perf|ci)(\(.+\))?: .+"; then
  echo "❌ Commit message does not follow Conventional Commits format!"
  echo ""
  echo "Format: <type>(<scope>): <subject>"
  echo ""
  echo "Types:"
  echo "  feat     - New feature"
  echo "  fix      - Bug fix"
  echo "  docs     - Documentation"
  echo "  style    - Code style"
  echo "  refactor - Code refactoring"
  echo "  test     - Tests"
  echo "  chore    - Maintenance"
  echo "  perf     - Performance"
  echo "  ci       - CI/CD"
  echo ""
  echo "Examples:"
  echo "  feat(auth): add login functionality"
  echo "  fix(network): handle timeout errors"
  echo "  docs(readme): update installation guide"
  exit 1
fi

exit 0
EOF

# Create pre-push hook
cat > .githooks/pre-push << 'EOF'
#!/bin/bash

echo "Running pre-push checks..."

# Check if Flutter is available
if ! command -v flutter &> /dev/null; then
  echo "⚠️  Flutter not found. Skipping tests."
  exit 0
fi

# Run tests
echo "🧪 Running tests..."
flutter test || {
  echo "❌ Tests failed!"
  exit 1
}

echo "✅ Pre-push checks passed!"
exit 0
EOF

# Make hooks executable
chmod +x .githooks/*

# Install hooks
if [ -d ".git/hooks" ]; then
  cp .githooks/* .git/hooks/
  chmod +x .git/hooks/*
  echo "✅ Git hooks installed successfully!"
else
  echo "❌ .git/hooks directory not found. Are you in a Git repository?"
  exit 1
fi
```

### Usage

```bash
# Run setup script
chmod +x scripts/setup-git-hooks.sh
./scripts/setup-git-hooks.sh
```

---

## What Each Hook Does

### Pre-commit Hook

Runs before each commit:
- ✅ Code formatting check (`dart format`)
- ✅ Code analysis (`flutter analyze`)

**Purpose:** Ensure code quality before committing

### Commit-msg Hook

Validates commit message format:
- ✅ Checks Conventional Commits format
- ✅ Provides helpful error messages

**Purpose:** Maintain consistent commit history

### Pre-push Hook

Runs before pushing to remote:
- ✅ Runs all tests (`flutter test`)

**Purpose:** Prevent pushing broken code

---

## Customization

### Skip Hooks (When Needed)

Sometimes you need to skip hooks:

```bash
# Skip pre-commit hook
git commit --no-verify -m "feat: emergency fix"

# Skip pre-push hook
git push --no-verify
```

**⚠️ Use sparingly!** Only when absolutely necessary.

### Add More Checks

You can add more checks to hooks:

```bash
# In pre-commit hook, add:
# - Check for TODO/FIXME comments
# - Check for console.log statements
# - Check file sizes
# - Run specific tests
```

### Platform-Specific Hooks

For Windows, create `.githooks/pre-commit.bat`:

```batch
@echo off
echo Running pre-commit checks...
dart format --set-exit-if-changed .
if %errorlevel% neq 0 (
  echo Code formatting check failed!
  exit /b 1
)
flutter analyze
if %errorlevel% neq 0 (
  echo Code analysis failed!
  exit /b 1
)
echo Pre-commit checks passed!
exit /b 0
```

---

## Troubleshooting

### Hooks Not Running

1. **Check if hooks are installed:**
   ```bash
   ls -la .git/hooks/
   ```

2. **Check if hooks are executable:**
   ```bash
   chmod +x .git/hooks/*
   ```

3. **Reinstall hooks:**
   ```bash
   ./scripts/setup-git-hooks.sh
   ```

### Hooks Too Slow

If hooks are too slow, you can:

1. **Run checks only on changed files** (more complex)
2. **Use `--no-verify` for quick commits** (not recommended)
3. **Optimize checks** - Remove unnecessary checks

### Platform Issues

- **Windows:** Use `.bat` files or Git Bash
- **macOS/Linux:** Use shell scripts (`.sh`)

---

## Best Practices

1. ✅ **Keep hooks fast** - Don't run slow operations in pre-commit
2. ✅ **Provide clear error messages** - Help developers fix issues
3. ✅ **Allow skipping** - Sometimes you need `--no-verify`
4. ✅ **Document hooks** - Explain what each hook does
5. ✅ **Test hooks** - Make sure they work on all platforms

---

## Comparison with Husky

| Feature | Husky (Node.js) | git_hooks (Dart) | Manual Hooks |
|---------|----------------|------------------|--------------|
| Setup | `npm install` | `pub add` | Scripts |
| Configuration | `.husky/` | Dart code | Shell scripts |
| Dependencies | Yes | Yes | No |
| Platform Support | All | All | All |
| Customization | Easy | Easy | Flexible |
| Popularity | Very High | Medium | Low |

---

## Next Steps

1. **Choose your approach** - `git_hooks`, manual hooks, or Husky
2. **Set up hooks** - Follow the setup guide above
3. **Test hooks** - Make a test commit to verify
4. **Customize** - Adjust hooks to your team's needs
5. **Document** - Update team documentation

---

**Questions?** Open an issue or check the [Contributing Guide](../CONTRIBUTING.md).

