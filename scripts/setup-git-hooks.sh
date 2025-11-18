#!/bin/bash

# Git Hooks Setup Script for Flutter Starter
# This script sets up Git hooks for code quality checks

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
  echo ""
  echo "Hooks installed:"
  echo "  - pre-commit: Format check + code analysis"
  echo "  - commit-msg: Conventional Commits validation"
  echo "  - pre-push: Run tests"
  echo ""
  echo "To skip hooks (when needed):"
  echo "  git commit --no-verify"
  echo "  git push --no-verify"
else
  echo "❌ .git/hooks directory not found. Are you in a Git repository?"
  exit 1
fi

