#!/usr/bin/env bash
# A format *check* must report, not rewrite (koniz-dev/flutter-starter#341).
#
# In a scratch copy of the tracked tree with one misformatted file planted
# under tool/:
#   1. format_dart.sh --check exits non-zero and leaves `git status
#      --porcelain` exactly as it was;
#   2. the acceptance runner's format gate is format_dart.sh --check, so (1)
#      covers it;
#   3. format_dart.sh without --check still formats the file.
#
# Usage: scripts/test/format_check_test.sh   (from the repository root)
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }

# Tracked files that still exist: a strip job deletes some without
# unstaging them, and rsync would fail on the missing paths.
(cd "$ROOT" && git ls-files -z | while IFS= read -r -d '' f; do
  [[ -e "$f" ]] && printf '%s\0' "$f"
done) | rsync -a --from0 --files-from=- "$ROOT/" "$WORK/"
cd "$WORK" || exit 1
git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -qm base
flutter pub get >/dev/null 2>&1 || dart pub get >/dev/null 2>&1
git checkout -q -- . 2>/dev/null # drop pub-get churn so the baseline is clean

printf 'void   probe( ) {}\n' > tool/zz_format_probe.dart
before="$(git status --porcelain)"

./scripts/dev/format_dart.sh --check >/dev/null 2>&1
rc=$?
after="$(git status --porcelain)"
if [[ $rc -eq 0 ]]; then fail "format_dart.sh --check exited 0 on a misformatted tree"; fi
if [[ "$before" != "$after" ]]; then
  fail "format_dart.sh --check changed the working tree:"
  diff <(echo "$before") <(echo "$after")
fi
if [[ "$(cat tool/zz_format_probe.dart)" != 'void   probe( ) {}' ]]; then
  fail "format_dart.sh --check rewrote tool/zz_format_probe.dart"
fi
echo "format_dart.sh --check: exit $rc, working tree unchanged: $([[ "$before" == "$after" ]] && echo yes || echo no)"

# shellcheck disable=SC2016 # the \$ is a literal in the pattern, not an expansion
if ! grep -qE '^run format +"format check" +"\$ROOT/scripts/dev/format_dart\.sh" --check$' scripts/test/run_acceptance.sh; then
  fail "run_acceptance.sh's format gate does not go through format_dart.sh --check"
else
  echo "run_acceptance.sh format gate: format_dart.sh --check"
fi

./scripts/dev/format_dart.sh >/dev/null 2>&1
if [[ "$(cat tool/zz_format_probe.dart)" != 'void probe() {}' ]]; then
  fail "format_dart.sh (no --check) did not format the file"
else
  echo "format_dart.sh (no --check): formatted the file"
fi

if [[ $failures -gt 0 ]]; then
  echo "$failures failure(s)"
  exit 1
fi
echo "OK"
