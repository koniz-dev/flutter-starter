#!/usr/bin/env bash
# Enforce invariant 3 of docs/issue-workflow.md: commits and PR bodies LINK to
# an issue, they never CLOSE it.
#
# Two rules, applied to every commit message in a range and to a PR body:
#
#   1. No GitHub auto-closing syntax. A keyword placed directly before an issue
#      reference ("Closes #12", "fixes koniz-dev/flutter-starter#12") closes the
#      issue the moment the commit lands on the default branch - at MERGE time,
#      before anything has run the acceptance criteria. That destroys the
#      verification gate the whole workflow is built around.
#   2. A `Refs owner/repo#N` reference must be present, so the change is
#      traceable back to the issue that justified it.
#
# The keyword is only matched where GitHub would actually act on it: directly
# before the reference. Prose that merely begins with the word - PR #44's
# "Closes out the investigation in #40" - does not auto-close anything and is
# not flagged. A blanket `grep -i closes` would have failed that PR and taught
# everyone to ignore this check.
#
# Usage:
#   scripts/dev/check_issue_refs.sh --range origin/main..HEAD
#   scripts/dev/check_issue_refs.sh --body-file pr-body.txt
#   scripts/dev/check_issue_refs.sh --range A..B --body-file pr-body.txt
#   REPO=owner/name scripts/dev/check_issue_refs.sh --range A..B
#
# Exits 0 when everything conforms, 1 on any violation, 2 on a usage error.
set -uo pipefail

REPO_SLUG="${REPO:-koniz-dev/flutter-starter}"

RANGE=""
BODY_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --range)
      RANGE="${2:-}"
      [[ -z "$RANGE" ]] && { echo "--range needs a git range" >&2; exit 2; }
      shift 2
      ;;
    --body-file|--message-file)
      BODY_FILE="${2:-}"
      [[ -z "$BODY_FILE" ]] && { echo "$1 needs a path" >&2; exit 2; }
      shift 2
      ;;
    -h|--help)
      awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$RANGE" && -z "$BODY_FILE" ]]; then
  echo "Nothing to check. Pass --range and/or --body-file (--help for usage)." >&2
  exit 2
fi

# Written out in full rather than as `fix(|es|ed)`: empty alternation branches
# are a GNU extension and this has to behave identically under BSD grep on
# macOS and GNU grep on the CI runner.
KEYWORD='(close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)'
# `#12`, `owner/repo#12`, or the full issue URL - all three auto-close.
ISSUE_REF='(#[0-9]+|[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+#[0-9]+|https?://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/issues/[0-9]+)'
# Leading `(^|[^A-Za-z])` stands in for a word boundary, which is spelled
# differently in GNU and BSD regex.
BANNED="(^|[^A-Za-z])${KEYWORD}[[:space:]]*:?[[:space:]]*${ISSUE_REF}"
REQUIRED="[Rr]efs[[:space:]]+${REPO_SLUG}#[0-9]+"

FAILURES=0

# check_message <label> <file>
check_message() {
  local label="$1" file="$2" offender

  offender="$(grep -Eio "$BANNED" "$file" | head -n 1 || true)"
  if [[ -n "$offender" ]]; then
    echo "  FAIL  $label"
    echo "        auto-closing reference: '$(echo "$offender" | sed 's/^[^A-Za-z]*//')'"
    echo "        GitHub would close that issue at merge time, before the"
    echo "        acceptance criteria run. Use 'Refs ${REPO_SLUG}#N'."
    FAILURES=$((FAILURES + 1))
    return
  fi

  if ! grep -Eq "$REQUIRED" "$file"; then
    echo "  FAIL  $label"
    echo "        no 'Refs ${REPO_SLUG}#N' reference found."
    FAILURES=$((FAILURES + 1))
    return
  fi

  echo "  ok    $label"
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ -n "$RANGE" ]]; then
  echo "Commits in $RANGE"
  commits="$(git rev-list --no-merges "$RANGE" 2>/dev/null)"
  if [[ -z "$commits" ]]; then
    echo "  (no non-merge commits in range)"
  fi
  while IFS= read -r sha; do
    [[ -z "$sha" ]] && continue
    git log -1 --format=%B "$sha" >"$TMP_DIR/commit.txt"
    subject="$(git log -1 --format=%s "$sha")"
    check_message "${sha:0:8} $subject" "$TMP_DIR/commit.txt"
  done <<<"$commits"
  echo
fi

if [[ -n "$BODY_FILE" ]]; then
  if [[ ! -f "$BODY_FILE" ]]; then
    echo "Body file not found: $BODY_FILE" >&2
    exit 2
  fi
  echo "Body file $BODY_FILE"
  check_message "PR title and body" "$BODY_FILE"
  echo
fi

if [[ "$FAILURES" -gt 0 ]]; then
  echo "$FAILURES message(s) violate invariant 3 (docs/issue-workflow.md)."
  exit 1
fi

echo "OK: every message links with 'Refs ${REPO_SLUG}#N' and closes nothing."
