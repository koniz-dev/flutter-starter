#!/bin/bash
# Reads the summary `patrol test` prints and fails unless every collected
# test ran and passed.
#
# Usage: ./scripts/test/check_patrol_summary.sh <patrol-output.log>
#
# `patrol test` exits 0 on an empty test set, and on a set whose tests were
# all skipped: a run reporting "Total: 0", or "Total: 2 ... Skipped: 2", was
# green having verified nothing. So a run passes only when
#
#   - the log exists and has a "Test summary:" block with a "Total:" line;
#   - Total is not 0;
#   - Failed is 0 and Skipped is 0;
#   - Successful equals Total.
#
# Used by .github/workflows/e2e-android.yml and scripts/test/run_e2e_tests.sh,
# so the CI and local E2E paths apply one rule. Works on bash 3.2.

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <patrol-output.log>" >&2
    exit 2
fi
log="$1"

# GitHub renders ::error:: lines as annotations; a terminal should not see them.
prefix="Error: "
if [ -n "${GITHUB_ACTIONS:-}" ]; then prefix="::error::"; fi
die() {
    echo "${prefix}$1" >&2
    exit 1
}

[ -f "$log" ] || die "$log is missing - the test step never produced output."

# Only the block after the last "Test summary:" heading counts, and in it the
# first "<label>: <n>": a summary-shaped line printed elsewhere in the log
# (by the app under test, say) is not Patrol's verdict. -a: a NUL byte in the
# output must not make grep report "Binary file matches" instead of lines.
summary=$(awk '
    /Test summary:/ { block = ""; found = 1; next }
    found { block = block $0 "\n" }
    END { printf "%s", block }
' "$log")
count() {
    { printf '%s' "$summary" | grep -aoE "$1: *[0-9]+" || true; } | head -1 | grep -aoE '[0-9]+' || true
}
total=$(count Total)
successful=$(count Successful)
failed=$(count Failed)
skipped=$(count Skipped)

echo "Patrol reported: total=${total:-<none>} successful=${successful:-<none>}" \
    "failed=${failed:-<none>} skipped=${skipped:-<none>}"

[ -n "$total" ] || die "No 'Total:' summary in patrol output; cannot confirm any test ran."
[ "$total" -ne 0 ] || die "Patrol collected 0 tests. A green run here would be a false pass."
[ "${failed:-0}" -eq 0 ] || die "$failed of $total Patrol test(s) failed. See the Patrol output."
[ "${skipped:-0}" -eq 0 ] || die "$skipped of $total Patrol test(s) were skipped; a skipped test verified nothing."
[ -n "$successful" ] || die "No 'Successful:' count in patrol output; cannot confirm the tests passed."
[ "$successful" -eq "$total" ] || die "Only $successful of $total Patrol test(s) succeeded."

echo "OK: $total test(s) collected, all executed and passed."
