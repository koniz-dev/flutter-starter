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
# `pipefail` is load-bearing: run() pipes each command through sed to strip ANSI
# escapes, and without it the pipeline would report sed's exit status, turning
# every failing gate into a silent PASS.
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

run format   "format check"   dart format --set-exit-if-changed lib test integration_test tool examples
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
if [[ -d test/acceptance ]]; then
  while IFS= read -r png; do
    cp "$png" "$OUT/$(basename "$png")"
  done < <(find test/acceptance -name '*.png' -type f)
fi

echo
echo "Evidence written to $OUT/"
ls -1 "$OUT" | sed 's/^/  /'
echo

# Silent evidence loss is the worst failure mode this workflow has: `git add` on
# a directory skips ignored files WITHOUT erroring, so a session can believe it
# committed evidence while every link 404s. The root .gitignore has a `*.log`
# rule, re-included for this directory only. Verify that, loudly, every run.
#
# Test each file with `check-ignore -q --no-index`, which exits 0 only when the
# path is genuinely ignored. Do NOT parse `check-ignore -v` output: it prints the
# winning pattern even when that pattern is a NEGATION, so a correctly
# re-included file looks identical to a blocked one. `--no-index` makes the check
# independent of whether the file is already tracked.
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  blocked=()
  for f in "$OUT"/*; do
    [[ -f "$f" ]] || continue
    if git check-ignore -q --no-index "$f" 2>/dev/null; then
      blocked+=("$f")
    fi
  done
  if (( ${#blocked[@]} )); then
    echo "ERROR: git is ignoring evidence files, so they cannot be committed:"
    printf '  %s\n' "${blocked[@]}"
    echo
    echo "Fix .gitignore (the '!docs/verification/**/*.log' negation) before"
    echo "closing any issue against this evidence. Do NOT use 'git add -f':"
    echo "the next session would hit the same trap."
    exit 1
  fi
fi


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
