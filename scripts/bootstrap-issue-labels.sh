#!/usr/bin/env bash
# Bootstrap the issue-driven workflow labels for this repository.
#
# This script is the CANONICAL SOURCE for the epic:* list. Humans, agents, and
# any issue-filing integration must read epics from here (or from
# `--list-epics`) rather than re-typing them, so the three cannot drift apart.
# See docs/issue-workflow.md and CLAUDE.md ("Workflow").
#
# Idempotent: uses `gh label create --force`, so re-running updates colors and
# descriptions in place instead of failing on existing labels.
#
# Usage:
#   ./scripts/bootstrap-issue-labels.sh                  # apply to this repo
#   REPO=owner/name ./scripts/bootstrap-issue-labels.sh  # apply elsewhere
#   ./scripts/bootstrap-issue-labels.sh --dry-run        # print, change nothing
#   ./scripts/bootstrap-issue-labels.sh --list-epics     # epic slugs, one per line
#   ./scripts/bootstrap-issue-labels.sh --prune-defaults  # also delete the stock
#                                                         # GitHub labels that
#                                                         # duplicate type:*
#
# NOTE ON ISSUE TYPES: GitHub's native issue types (Bug / Feature / Task) are an
# ORGANISATION-level feature. This repository is owned by a user account, so
# types are unavailable and cannot be created by any script. The type:* label
# family below stands in for them. If the repo ever moves to an organisation,
# see the migration note in docs/issue-workflow.md.
set -euo pipefail

DRY_RUN=0
PRUNE_DEFAULTS=0
LIST_EPICS_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --prune-defaults) PRUNE_DEFAULTS=1 ;;
    --list-epics) LIST_EPICS_ONLY=1 ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

# ---------------------------------------------------------------------------
# Epics — the canonical functional split of this repository.
# Format: slug|description
# Keep each slug mapped to a real directory or surface in the tree.
# ---------------------------------------------------------------------------
EPICS=(
  "core-network|lib/core/network: Dio ApiClient, interceptors, realtime/WebSocket"
  "core-storage|lib/core/storage: key-value + secure adapters, token store, migrations"
  "core-security|lib/core/security: RASP providers, hardening, security docs"
  "core-config|lib/core/config: env layers, .env, dart-defines, feature flags plumbing"
  "core-routing|lib/core/routing: GoRouter tree, guards, navigation adapters"
  "feature-auth|lib/features/auth: login, register, session (sample feature slice)"
  "feature-tasks|lib/features/tasks: CRUD sample feature slice"
  "design-system|lib/shared: design tokens, theme, shared widgets, accessibility"
  "testing|test/, integration_test/, coverage gates, Patrol E2E, golden acceptance"
  "tooling-ci|.github/workflows, scripts/, tool/, bricks/, git hooks"
  "docs|docs/, README, CONTRIBUTING, CHANGELOG"
)

if [[ "$LIST_EPICS_ONLY" -eq 1 ]]; then
  for e in "${EPICS[@]}"; do echo "epic:${e%%|*}"; done
  exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: the GitHub CLI (gh) is required. See https://cli.github.com" >&2
  exit 1
fi

REPO="${REPO:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
echo "Target repository: $REPO"
[[ "$DRY_RUN" -eq 1 ]] && echo "(dry run - no changes will be made)"
echo

# create_label <name> <color> <description>
create_label() {
  local name="$1" color="$2" desc="$3"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '  would create/update  %-28s #%s  %s\n' "$name" "$color" "$desc"
    return 0
  fi
  gh label create "$name" \
    --repo "$REPO" \
    --color "$color" \
    --description "$desc" \
    --force >/dev/null
  printf '  ok  %-28s #%s\n' "$name" "$color"
}

# ---------------------------------------------------------------------------
# type:* — stand-in for GitHub native issue types (org-only feature).
# ---------------------------------------------------------------------------
echo "type:* (stands in for native issue types)"
create_label "type:bug"     "d73a4a" "Something that is broken relative to documented behavior"
create_label "type:feature" "a2eeef" "New capability or user-visible enhancement"
create_label "type:task"    "c5def5" "Chore, refactor, docs, or tooling work with no new capability"
echo

# ---------------------------------------------------------------------------
# epic:* — functional area. Exactly one per issue.
# ---------------------------------------------------------------------------
echo "epic:* (functional area; exactly one per issue)"
for entry in "${EPICS[@]}"; do
  create_label "epic:${entry%%|*}" "5319e7" "${entry#*|}"
done
echo

# ---------------------------------------------------------------------------
# priority:* — queue order. Exactly one per issue.
# ---------------------------------------------------------------------------
echo "priority:* (queue order; exactly one per issue)"
create_label "priority:P0" "b60205" "Drop everything: main is broken, released build is unusable, or a security hole"
create_label "priority:P1" "d93f0b" "Next up: blocks adopters or a documented workflow is wrong"
create_label "priority:P2" "fbca04" "Normal queue: real but not blocking"
create_label "priority:P3" "0e8a16" "Nice to have: cosmetic, speculative, or long tail"
echo

# ---------------------------------------------------------------------------
# status:* — lifecycle state. AT MOST one per issue, and EXACTLY one on any
# open issue that has been triaged. See invariant 1 in docs/issue-workflow.md.
# ---------------------------------------------------------------------------
echo "status:* (lifecycle state; exactly one per triaged open issue)"
create_label "status:todo"        "e4e4e4" "Triaged and startable: has acceptance criteria, nobody assigned"
create_label "status:in-progress" "0052cc" "Claimed by an assignee and being worked right now"
create_label "status:needs-uat"   "d876e3" "Shipped, but acceptance criteria need a HUMAN to verify"
create_label "status:blocked"     "7f1d1d" "Cannot proceed: needs a decision, credential, or upstream fix"
echo

# ---------------------------------------------------------------------------
# Optional: remove stock GitHub labels that duplicate type:*.
# Not run by default - deleting a label strips it from every historical issue.
# ---------------------------------------------------------------------------
if [[ "$PRUNE_DEFAULTS" -eq 1 ]]; then
  echo "Pruning stock GitHub labels that duplicate type:*"
  for stale in bug enhancement documentation duplicate invalid question wontfix; do
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "  would delete  $stale"
    elif gh label delete "$stale" --repo "$REPO" --yes >/dev/null 2>&1; then
      echo "  deleted  $stale"
    else
      echo "  skipped  $stale (absent)"
    fi
  done
  echo
fi

echo "Done. Labels are the source of truth for issue state; any Project board is"
echo "a read-only mirror. See docs/issue-workflow.md."
