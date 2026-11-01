#!/usr/bin/env bash

# Tests for .githooks/pre-commit in a fresh clone.
#
# Usage: ./scripts/test/pre_commit_hook_test.sh
#
# Before `flutter pub get`, `dart format` cannot resolve the very_good_analysis
# include in analysis_options.yaml, formats with the wrong settings, and the
# hook used to rewrite ~100 untouched files before failing the commit. This
# clones the repository locally (committed HEAD, no .dart_tool/) and runs the
# hook under test from outside the clone, so the hook file itself never
# dirties the tree it is judging.
#
#   1. No package_config.json: the hook exits non-zero, tells the user to run
#      `flutter pub get`, and `git status --porcelain` stays empty.
#   2. After `flutter pub get`: the hook exits 0 on the clean tree. It
#      checks the staged content, so it still exits 0 when a format violation
#      is only in the working copy, and exits non-zero once it is staged.
#   3. The app in a subdirectory of a larger repository (a monorepo): git runs
#      the hook from the top, as <app>/.githooks/pre-commit. It checks the
#      app, so it exits 0 on a clean tree and non-zero on a staged violation.
#   4. The app as a member of a pub workspace (root pubspec.yaml with
#      `workspace:`, the app with `resolution: workspace`): pub writes
#      package_config.json only at the workspace root, so the app has none of
#      its own. The hook still exits 0 on a clean tree and non-zero on a
#      staged violation, also with a Windows-style (backslash) workspaceRoot;
#      with the workspace unresolved it refuses, and after the
#      `flutter pub get` it advises, it passes.
#
# HOOK_UNDER_TEST=<file> points the tests at another copy of the hook, for
# example an older revision, to show a case fails there.
#
# Needs Flutter on PATH. Run in CI by .github/workflows/git-hooks.yml.
# Exits non-zero when any case fails.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="${HOOK_UNDER_TEST:-$ROOT/.githooks/pre-commit}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

FAILURES=0
pass() { echo "ok    $1"; }
fail() { echo "FAIL  $1"; FAILURES=$((FAILURES + 1)); }

if ! command -v flutter >/dev/null 2>&1; then
  echo "FAIL  flutter is not on PATH; this test drives the real hook"
  exit 1
fi

CLONE="$WORK/clone"
git clone -q --no-hardlinks "$ROOT" "$CLONE"

run_hook() {
  (cd "$CLONE" && bash "$HOOK") >"$WORK/hook.out" 2>&1
}

# --- Case 1: dependencies not resolved -------------------------------------
if [ -e "$CLONE/.dart_tool/package_config.json" ]; then
  fail "fresh clone unexpectedly has .dart_tool/package_config.json"
fi

run_hook
status=$?
echo "--- hook output without pub get (exit $status) ---"
cat "$WORK/hook.out"
echo "---"

if [ "$status" -ne 0 ]; then
  pass "without pub get the hook exits non-zero"
else
  fail "without pub get the hook exited 0"
fi
if grep -q "flutter pub get" "$WORK/hook.out"; then
  pass "without pub get the hook tells the user to run flutter pub get"
else
  fail "without pub get the hook does not mention flutter pub get"
fi
dirty="$(git -C "$CLONE" status --porcelain)"
if [ -z "$dirty" ]; then
  pass "without pub get the hook rewrites nothing (git status --porcelain is empty)"
else
  fail "without pub get the hook left $(printf '%s\n' "$dirty" | wc -l | tr -d ' ') changed path(s)"
  printf '%s\n' "$dirty" | head -10
fi

# --- Case 2: dependencies resolved -----------------------------------------
# pub get leaves the clone clean on the current stable; if a new
# stable makes it dirty a tracked file, that is not the hook's doing, and this
# case judges only the hook's exit status anyway.
(cd "$CLONE" && flutter pub get >/dev/null 2>&1) || fail "flutter pub get failed in the clone"

run_hook
status=$?
if [ "$status" -eq 0 ]; then
  pass "with dependencies resolved the hook exits 0 on a clean tree"
else
  fail "with dependencies resolved the hook exited $status on a clean tree"
  tail -20 "$WORK/hook.out"
fi

printf '\nvoid   badlyFormatted( ){}\n' >>"$CLONE/lib/main.dart"
run_hook
status=$?
if [ "$status" -eq 0 ]; then
  pass "an unstaged format violation over a clean index does not fail the hook"
else
  fail "an unstaged format violation failed the hook (exit $status)"
  tail -20 "$WORK/hook.out"
fi

git -C "$CLONE" add lib/main.dart
run_hook
status=$?
if [ "$status" -ne 0 ] && grep -q "formatting check failed" "$WORK/hook.out"; then
  pass "with dependencies resolved the hook fails on a staged format violation"
else
  fail "a staged format violation did not fail the hook (exit $status)"
  tail -20 "$WORK/hook.out"
fi

# --- Case 3: the app in a subdirectory of a larger repository --------------
# A copy of the resolved clone, without its .git, as mono/app. The hook under
# test is copied into the app's .githooks/ - this repository is a fixture,
# so that dirties nothing - and run from the top, the way git runs it.
MONO="$WORK/mono"
mkdir -p "$MONO"
git -C "$MONO" init -q
git -C "$CLONE" reset -q
git -C "$CLONE" checkout -q -- lib/main.dart
cp -R "$CLONE" "$MONO/app"
rm -rf "$MONO/app/.git"
cp "$HOOK" "$MONO/app/.githooks/pre-commit"
git -C "$MONO" add -A
git -C "$MONO" -c user.email=t@example.com -c user.name=t commit -q --no-verify -m "chore: monorepo fixture"

run_mono_hook() {
  (cd "$MONO" && bash app/.githooks/pre-commit) >"$WORK/hook.out" 2>&1
}

run_mono_hook
status=$?
if [ "$status" -eq 0 ]; then
  pass "in a monorepo the hook checks the app and exits 0 on a clean tree"
else
  fail "in a monorepo the hook exited $status on a clean tree"
  tail -20 "$WORK/hook.out"
fi

printf '\nvoid   badlyFormatted( ){}\n' >>"$MONO/app/lib/main.dart"
git -C "$MONO" add app/lib/main.dart
run_mono_hook
status=$?
if [ "$status" -ne 0 ] && grep -q "formatting check failed" "$WORK/hook.out"; then
  pass "in a monorepo the hook fails on a staged format violation in the app"
else
  fail "in a monorepo a staged format violation did not fail the hook (exit $status)"
  tail -20 "$WORK/hook.out"
fi

# --- Case 4: the app as a member of a pub workspace ------------------------
# The monorepo again, now with a root pubspec.yaml declaring the workspace and
# the app resolving through it. The root takes the app's own environment, so
# the same SDK resolves both.
WS="$WORK/ws"
mkdir -p "$WS"
git -C "$WS" init -q
# Undo case 3's staged violation first, or the fixture starts dirty.
git -C "$MONO" reset -q
git -C "$MONO" checkout -q -- app/lib/main.dart
cp -R "$MONO/app" "$WS/app"
rm -rf "$WS/app/.dart_tool" "$WS/app/pubspec.lock"
env_block="$(sed -n '/^environment:/,/^[^[:space:]]/p' "$WS/app/pubspec.yaml" | sed '$d')"
{
  echo "name: workspace_root"
  echo "publish_to: none"
  printf '%s\n' "$env_block"
  echo "workspace:"
  echo "  - app"
} >"$WS/pubspec.yaml"
# `resolution: workspace` goes right after the environment block.
awk '
  /^environment:/ { in_env = 1; print; next }
  in_env && !/^[[:space:]]/ { print "resolution: workspace"; in_env = 0 }
  { print }
' "$WS/app/pubspec.yaml" >"$WS/app/pubspec.yaml.new" && mv "$WS/app/pubspec.yaml.new" "$WS/app/pubspec.yaml"
(cd "$WS/app" && flutter pub get >/dev/null 2>&1) || fail "flutter pub get failed in the workspace member"
if [ -f "$WS/.dart_tool/package_config.json" ] && [ ! -f "$WS/app/.dart_tool/package_config.json" ] \
  && [ -f "$WS/app/.dart_tool/pub/workspace_ref.json" ]; then
  pass "the workspace fixture resolves at its root only (the layout under test)"
else
  fail "the workspace fixture did not resolve as a pub workspace"
fi
# As in any real workspace, the root's resolved state is not committed - so
# the hook's export has no config until the hook copies the root's in.
echo ".dart_tool/" >"$WS/.gitignore"
git -C "$WS" add -A
git -C "$WS" -c user.email=t@example.com -c user.name=t commit -q --no-verify -m "chore: workspace fixture"
if git -C "$WS" ls-files | grep -q '\.dart_tool/'; then
  fail "the workspace fixture committed a .dart_tool/ directory"
fi

run_ws_hook() {
  (cd "$WS" && bash app/.githooks/pre-commit) >"$WORK/hook.out" 2>&1
}

run_ws_hook
status=$?
if [ "$status" -eq 0 ]; then
  pass "in a pub workspace the hook exits 0 on a clean tree"
else
  fail "in a pub workspace the hook exited $status on a clean tree"
  tail -20 "$WORK/hook.out"
fi

printf '\nvoid   badlyFormatted( ){}\n' >>"$WS/app/lib/main.dart"
git -C "$WS" add app/lib/main.dart
run_ws_hook
status=$?
if [ "$status" -ne 0 ] && grep -q "formatting check failed" "$WORK/hook.out"; then
  pass "in a pub workspace the hook fails on a staged format violation"
else
  fail "in a pub workspace a staged format violation did not fail the hook (exit $status)"
  tail -20 "$WORK/hook.out"
fi
git -C "$WS" reset -q
git -C "$WS" checkout -q -- app/lib/main.dart

# pub on Windows writes workspaceRoot with JSON-escaped backslashes.
ref="$WS/app/.dart_tool/pub/workspace_ref.json"
cp "$ref" "$WORK/workspace_ref.json.bak"
# The same path pub wrote here, with each / as an escaped backslash.
sed 's#/#\\\\#g' "$WORK/workspace_ref.json.bak" >"$ref"
grep -qF '..\\..' "$ref" || fail "the Windows-style workspace_ref.json fixture has no escaped backslash"
run_ws_hook
status=$?
if [ "$status" -eq 0 ]; then
  pass "in a pub workspace the hook follows a Windows-style workspaceRoot"
else
  fail "with a Windows-style workspaceRoot the hook exited $status on a clean tree"
  cat "$ref"
  tail -20 "$WORK/hook.out"
fi
cp "$WORK/workspace_ref.json.bak" "$ref"

rm -f "$WS/.dart_tool/package_config.json"
run_ws_hook
status=$?
if [ "$status" -ne 0 ] && grep -q "flutter pub get" "$WORK/hook.out"; then
  pass "with the workspace unresolved the hook refuses and advises flutter pub get"
else
  fail "with the workspace unresolved the hook did not refuse with advice (exit $status)"
  tail -20 "$WORK/hook.out"
fi
(cd "$WS/app" && flutter pub get >/dev/null 2>&1) || fail "flutter pub get failed in the workspace member"
run_ws_hook
status=$?
if [ "$status" -eq 0 ]; then
  pass "after the advised flutter pub get the hook passes in the workspace"
else
  fail "after flutter pub get the hook still exited $status in the workspace"
  tail -20 "$WORK/hook.out"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All pre-commit hook cases passed."
  exit 0
fi
echo "$FAILURES case(s) failed."
exit 1
