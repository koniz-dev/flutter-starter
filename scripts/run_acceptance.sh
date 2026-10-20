#!/usr/bin/env bash
# Run the acceptance layer for an issue and write retrievable evidence.
#
# This is the harness referenced by process.md ("Acceptance verification") and
# issue-workflow.md on the maintainers branch. Run it FROM THE MAIN CHECKOUT: it
# runs the same gates as CI plus the golden-tagged acceptance tests that
# `flutter test` skips by default, and tees everything into the evidence
# worktree's docs/verification/issue-<N>/ (EVIDENCE_DIR, default
# ../flutter-starter-evidence), so the output is committed on the evidence
# branch and never on main.
#
# Usage, from the main checkout ($M is the maintainers worktree):
#   $M/scripts/run_acceptance.sh 12               # verify issue 12
#   $M/scripts/run_acceptance.sh 12 --update      # regenerate goldens first
#   $M/scripts/run_acceptance.sh 12 --no-goldens  # skip the golden layer
#
# Exit status is non-zero if any gate fails, so a session can branch on it.
# A zero exit is NOT by itself a PASS: you must still open each captured PNG
# and confirm it shows the behaviour the acceptance criteria assert.
# `pipefail` is load-bearing: run() pipes each command through sed to strip ANSI
# escapes, and without it the pipeline would report sed's exit status, turning
# every failing gate into a silent PASS.
set -uo pipefail

# The project under test is the checkout this is run from, not this branch.
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$ROOT" || ! -f "$ROOT/pubspec.yaml" ]]; then
  echo "Run this from a checkout of main (no pubspec.yaml above $PWD)." >&2
  exit 2
fi
cd "$ROOT" || exit 1
EVIDENCE_DIR="${EVIDENCE_DIR:-$ROOT/../flutter-starter-evidence}"
if [[ ! -d "$EVIDENCE_DIR/docs/verification" ]]; then
  echo "No evidence worktree at $EVIDENCE_DIR. Create it once with:" >&2
  echo "  git worktree add $EVIDENCE_DIR origin/evidence" >&2
  exit 2
fi

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

OUT="$EVIDENCE_DIR/docs/verification/issue-$ISSUE"
mkdir -p "$OUT"
FAILED=()

# Evidence has to stay reviewable and committable. `flutter test` emits the
# app's own logging for every test, which ran to ~577 KB for a three-file
# change on the first use of this script. So: strip ANSI escapes always, and on
# PASS keep only a head+tail excerpt. A FAILING log is kept in full - that is
# when you need every line.
MAX_LOG_LINES=200

# shrink_log <file>
shrink_log() {
  local f="$1"
  local total
  total=$(wc -l <"$f" | tr -d ' ')
  [[ "$total" -le "$MAX_LOG_LINES" ]] && return 0
  {
    head -n 60 "$f"
    echo
    echo "[... $((total - 120)) lines elided by scripts/test/run_acceptance.sh."
    echo "     Full output is reproducible by re-running the command above. ...]"
    echo
    tail -n 60 "$f"
  } >"$f.trimmed" && mv "$f.trimmed" "$f"
}

# run <slug> <human label> <command...>
run() {
  local slug="$1"; shift
  local label="$1"; shift
  local log="$OUT/$slug.log"
  echo "==> $label"
  {
    echo "\$ $*"
    echo
  } >"$log"
  # Strip ANSI colour, then collapse carriage returns to the final state of each
  # line. The compact reporter redraws one progress line with \r, so without this
  # a "124 line" log is still tens of kilobytes of overwritten progress text.
  if "$@" 2>&1 | sed -e $'s/\033\[[0-9;]*m//g' -e $'s/.*\r//' >>"$log"; then
    echo "exit: 0" >>"$log"
    shrink_log "$log"
    echo "    PASS  (log: $log)"
  else
    echo "exit: non-zero" >>"$log"
    echo "    FAIL  (log: $log)"
    FAILED+=("$label")
  fi
}

# Through format_dart.sh, the one owner of the scope, whose --check only
# reports (koniz-dev/flutter-starter#341).
run format   "format check"   "$ROOT/scripts/dev/format_dart.sh" --check
run analyze  "flutter analyze" flutter analyze
run tests    "flutter test (unit + widget, goldens skipped)" \
  flutter test --timeout=5m --reporter compact

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
# Only when the golden layer actually ran: copying goldens into the evidence
# directory of a non-visual issue invites a PASS table that cites a screenshot
# proving nothing.
if [[ "$RUN_GOLDENS" -eq 1 && -d test/acceptance ]]; then
  while IFS= read -r png; do
    cp "$png" "$OUT/$(basename "$png")"
  done < <(find test/acceptance -name '*.png' -type f)
fi

echo
echo "Evidence written to $OUT/"
ls -1 "$OUT" | sed 's/^/  /'
echo

# The evidence branch has no .gitignore, so every file written above commits
# there as is (koniz-dev/flutter-starter#619).

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
echo "  4. Commit $OUT/ in the evidence worktree and push it to the evidence"
echo "     branch (git -C $EVIDENCE_DIR push origin HEAD:refs/heads/evidence"
echo "     --no-verify), then link blob/evidence/docs/verification/issue-$ISSUE/..."
