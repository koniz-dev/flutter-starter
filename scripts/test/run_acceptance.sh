#!/usr/bin/env bash
# Run the acceptance layer for an issue and write retrievable evidence.
#
# This is the harness referenced by CLAUDE.md ("Acceptance verification") and
# docs/issue-workflow.md. It runs the same gates as CI plus the golden-tagged
# acceptance tests that `flutter test` skips by default, and tees everything
# into docs/verification/issue-<N>/ so the output can be committed and linked
# from the issue.
#
# Usage:
#   ./scripts/test/run_acceptance.sh 12               # verify issue 12
#   ./scripts/test/run_acceptance.sh 12 --update      # regenerate goldens first
#   ./scripts/test/run_acceptance.sh 12 --no-goldens  # skip the golden layer
#
# Exit status is non-zero if any gate fails, so a session can branch on it.
# A zero exit is NOT by itself a PASS: you must still open each captured PNG
# and confirm it shows the behaviour the acceptance criteria assert.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT"

ISSUE="${1:-}"
if [[ -z "$ISSUE" || ! "$ISSUE" =~ ^[0-9]+$ ]]; then
  echo "Usage: $0 <issue-number> [--update] [--no-goldens]" >&2
  exit 2
fi
shift

UPDATE_GOLDENS=0
RUN_GOLDENS=1
for arg in "$@"; do
  case "$arg" in
    --update) UPDATE_GOLDENS=1 ;;
    --no-goldens) RUN_GOLDENS=0 ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

OUT="docs/verification/issue-$ISSUE"
mkdir -p "$OUT"
FAILED=()

# run <slug> <human label> <command...>
run() {
  local slug="$1"; shift
  local label="$1"; shift
  echo "==> $label"
  if "$@" >"$OUT/$slug.log" 2>&1; then
    echo "    PASS  (log: $OUT/$slug.log)"
  else
    echo "    FAIL  (log: $OUT/$slug.log)"
    FAILED+=("$label")
  fi
}

run format   "format check"   dart format --set-exit-if-changed lib test integration_test tool examples
run analyze  "flutter analyze" flutter analyze
run tests    "flutter test (unit + widget, goldens skipped)" flutter test --timeout=5m

if [[ "$RUN_GOLDENS" -eq 1 && -d test/acceptance ]]; then
  if [[ "$UPDATE_GOLDENS" -eq 1 ]]; then
    echo "==> regenerating goldens"
    flutter test --run-skipped --tags golden --update-goldens test/acceptance \
      >"$OUT/goldens-update.log" 2>&1 \
      && echo "    goldens regenerated" \
      || { echo "    FAIL regenerating goldens"; FAILED+=("golden regeneration"); }
  fi
  run goldens "acceptance goldens" \
    flutter test --run-skipped --tags golden test/acceptance
fi

# Collect the PNGs this run verified so the evidence directory is self-contained.
if [[ -d test/acceptance ]]; then
  while IFS= read -r png; do
    cp "$png" "$OUT/$(basename "$png")"
  done < <(find test/acceptance -name '*.png' -type f)
fi

echo
echo "Evidence written to $OUT/"
ls -1 "$OUT" | sed 's/^/  /'
echo

if (( ${#FAILED[@]} )); then
  echo "RESULT: FAIL - ${#FAILED[@]} gate(s) failed:"
  printf '  - %s\n' "${FAILED[@]}"
  exit 1
fi

echo "RESULT: all gates passed."
echo
echo "NOT DONE YET. Before writing PASS on issue #$ISSUE you must:"
echo "  1. Open every PNG in $OUT/ and confirm it shows the asserted behaviour."
echo "     Remember: flutter test renders text as opaque blocks (Ahem font), so"
echo "     a golden cannot confirm wording - only layout, colour, and presence."
echo "  2. Walk each line of the issue's '## Acceptance criteria' and state which"
echo "     artifact proves it."
echo "  3. Route any criterion this harness cannot drive to status:needs-uat."
