#!/usr/bin/env bash
# Non-platform quality gate: env asset guard, generated code up to date,
# format (scoped), analyze, unit/widget tests.
# Does not run Android/iOS/Web builds or Patrol E2E.
#
# Usage: ./scripts/dev/audit_template.sh [flutter test arguments]
#
#   AUDIT_SKIP_CODEGEN=1  skip the generated-code check. It runs build_runner,
#                         which is the slowest step; skip it only when no
#                         annotated source (Freezed, json_serializable,
#                         Riverpod) changed.
#
# The CI Quality gate runs the same steps, plus three this script does not:
# tests in random order, the total line coverage floor (COVERAGE_MIN_TOTAL in
# ci.yml, see scripts/test/test_coverage.sh), and a check that pub get,
# analyze and test left every tracked file unchanged.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT"

# Content hashes of every generated file in the working tree, tracked or not.
generated_hashes() {
  git ls-files -z --cached --others --exclude-standard -- '*.g.dart' '*.freezed.dart' |
    sort -z | xargs -0 shasum -a 256 2>/dev/null || true
}

echo "==> env asset guard"
dart run tool/check_env_assets.dart

if [ "${AUDIT_SKIP_CODEGEN:-}" = "1" ]; then
  echo "==> generated code (skipped: AUDIT_SKIP_CODEGEN=1)"
else
  echo "==> generated code (build_runner build -d)"
  # Compared against the working tree, not HEAD: freshly regenerated files
  # that are not committed yet are not drift.
  before="$(generated_hashes)"
  dart run build_runner build -d >/dev/null
  after="$(generated_hashes)"
  if [ "$before" != "$after" ]; then
    echo "build_runner rewrote generated files; they did not match their sources:" >&2
    diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") |
      sed -n 's/^[<>] [0-9a-f]*  //p' | sort -u | sed 's/^/  /' >&2 || true
    echo "The regenerated files are now in the working tree; review and commit them." >&2
    exit 1
  fi
  echo "Generated code matches its sources."
fi

echo "==> format ($("$SCRIPT_DIR/format_dart.sh" --print-paths))"
"$SCRIPT_DIR/format_dart.sh" --check
echo "==> flutter analyze"
flutter analyze
echo "==> flutter test"
flutter test "$@"
