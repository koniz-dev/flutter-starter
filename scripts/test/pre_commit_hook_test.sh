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

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "All pre-commit hook cases passed."
  exit 0
fi
echo "$FAILURES case(s) failed."
exit 1
