#!/usr/bin/env bash
# Installs repository hooks from .githooks/ into .git/hooks/
# (.githooks/ is the single source of truth — do not duplicate hook bodies here.)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

HOOK_SRC="$ROOT/.githooks"
HOOK_DST="$ROOT/.git/hooks"

if [ ! -d "$HOOK_SRC" ]; then
  echo "❌ Missing $HOOK_SRC"
  exit 1
fi

if [ ! -d "$HOOK_DST" ]; then
  echo "❌ Not a Git repository (no .git/hooks). Run from repo root."
  exit 1
fi

required=(pre-commit commit-msg pre-push)
for name in "${required[@]}"; do
  if [ ! -f "$HOOK_SRC/$name" ]; then
    echo "❌ Required hook missing: $HOOK_SRC/$name"
    exit 1
  fi
done

echo "🔧 Installing hooks from .githooks/ → .git/hooks/ ..."
shopt -s nullglob
for f in "$HOOK_SRC"/*; do
  base="$(basename "$f")"
  # Only executable hook scripts (no accidental README etc.)
  case "$base" in
    pre-commit|commit-msg|pre-push)
      cp "$f" "$HOOK_DST/$base"
      chmod 755 "$HOOK_DST/$base"
      echo "   ✓ $base"
      ;;
  esac
done
shopt -u nullglob

echo ""
echo "✅ Git hooks installed."
echo "   pre-commit  → dart format (scoped) + flutter analyze"
echo "   commit-msg  → Conventional Commits"
echo "   pre-push    → flutter test (compact, timeout)"
echo ""
echo "Skip when needed: git commit --no-verify  |  git push --no-verify"
