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
#   ./scripts/bootstrap-issue-labels.sh --list-map       # epic:slug<TAB>path pairs
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
LIST_MAP_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --prune-defaults) PRUNE_DEFAULTS=1 ;;
    --list-epics) LIST_EPICS_ONLY=1 ;;
    --list-map) LIST_MAP_ONLY=1 ;;
    # Print the header comment and stop at the end of it. This used to be
    # `sed -n '2,30p'`, a hardcoded range that ran five lines past the comment
    # block and trailed off into `set -euo pipefail` and the flag variables.
    # Walking to the first non-comment line cannot drift as the header grows.
    -h|--help) awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"; exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

# ---------------------------------------------------------------------------
# Epics — the canonical functional split of this repository.
# Format: slug|description|space-separated paths
#
# The third field is the machine-readable half: every tracked surface a change
# can land in maps to exactly one epic, and `--list-map` emits that mapping for
# tooling. `tool/check_epic_coverage.dart`, run by
# `test/tooling/epic_coverage_test.dart`, fails if a surface is claimed by no
# epic or by two, or if an epic claims a path that is not in the tree. Adding a
# directory therefore means adding it here in the same change.
#
# Paths are repository-relative, use forward slashes, and must never contain a
# space or a `|`. A path claims everything beneath it unless a deeper path in
# this table claims a subtree explicitly (as `assets/` does).
# ---------------------------------------------------------------------------
EPICS=(
  "core-network|lib/core/network: Dio ApiClient, interceptors, realtime/WebSocket|lib/core/network"
  "core-storage|lib/core/storage: key-value + secure adapters, token store, migrations|lib/core/storage"
  "core-security|lib/core/security: RASP providers, hardening, security docs|lib/core/security"
  "core-config|lib/core/config, assets/config, .env.example: env layers, dart-defines|lib/core/config assets/config .env.example"
  "core-routing|lib/core/routing: GoRouter tree, guards, navigation adapters|lib/core/routing"
  "core-di|lib/core/di + lib/core/contracts: composition root, provider wiring, contracts|lib/core/di lib/core/contracts"
  "core-foundation|lib/core/{utils,errors,logging,performance,constants}: cross-cutting primitives|lib/core/utils lib/core/errors lib/core/logging lib/core/performance lib/core/constants"
  "feature-auth|lib/features/auth + lib/core/session: login, register, session (sample slice)|lib/features/auth lib/core/session"
  "feature-tasks|lib/features/tasks: CRUD sample feature slice|lib/features/tasks"
  "feature-flags|lib/features/feature_flags + lib/core/feature_flags: both halves of the flag stack|lib/features/feature_flags lib/core/feature_flags"
  "app-shell|lib/main.dart, lib/core/startup, lib/features/home: entry point and app shell|lib/main.dart lib/core/startup lib/features/home"
  "design-system|lib/shared + lib/core/accessibility + assets/images: tokens, theme, widgets, a11y|lib/shared lib/core/accessibility assets/images"
  "i18n|lib/l10n, lib/core/localization, l10n.yaml: ARB catalogs and locale plumbing|lib/l10n lib/core/localization l10n.yaml"
  "testing|test/, integration_test/, coverage gates, Patrol E2E, golden acceptance|test integration_test dart_test.yaml codecov.yml"
  "tooling-ci|.github, .githooks, scripts/, tool/, bricks/, analyzer and pubspec config|.github .githooks .vscode scripts tool bricks analysis_options.yaml pubspec.yaml pubspec.lock mason.yaml .gitignore .metadata"
  "docs|docs/, README, CONTRIBUTING, CHANGELOG, CLAUDE.md, .claude roles, examples/|docs examples .claude README.md CONTRIBUTING.md CHANGELOG.md CLAUDE.md LICENSE"
  "platform-release|android/ ios/ macos/ linux/ windows/ web/ fastlane/: native and release surfaces|android ios macos linux windows web fastlane flutter_launcher_icons.yaml flutter_native_splash.yaml"
)

# Split one EPICS entry into the globals EPIC_SLUG / EPIC_DESC / EPIC_PATHS.
# Fails loudly on a malformed entry rather than quietly creating a label with a
# truncated description, or an epic that claims nothing.
split_epic() {
  local entry="$1"
  IFS='|' read -r EPIC_SLUG EPIC_DESC EPIC_PATHS <<<"$entry"
  if [[ -z "$EPIC_SLUG" || -z "$EPIC_DESC" || -z "$EPIC_PATHS" ]]; then
    echo "ERROR: malformed EPICS entry (want slug|description|paths): $entry" >&2
    exit 2
  fi
}

if [[ "$LIST_EPICS_ONLY" -eq 1 ]]; then
  for e in "${EPICS[@]}"; do echo "epic:${e%%|*}"; done
  exit 0
fi

# One "epic:<slug><TAB><path>" line per claimed path. Like --list-epics this
# prints only what is in this file, so it must keep working with no gh, no
# authentication and no network.
if [[ "$LIST_MAP_ONLY" -eq 1 ]]; then
  for e in "${EPICS[@]}"; do
    split_epic "$e"
    for claimed_path in $EPIC_PATHS; do
      printf 'epic:%s\t%s\n' "$EPIC_SLUG" "$claimed_path"
    done
  done
  exit 0
fi

# `gh` is required only to CHANGE something. --dry-run and --list-epics print
# what this script knows and touch nothing, so they must work on a machine with
# no `gh` and no authentication - that is the whole point of a dry run.
if [[ "$DRY_RUN" -eq 0 ]] && ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: the GitHub CLI (gh) is required. See https://cli.github.com" >&2
  exit 1
fi

if [[ -z "${REPO:-}" ]]; then
  if command -v gh >/dev/null 2>&1; then
    # Still guard the call itself: `gh` can be installed but unauthenticated,
    # in which case this fails and a dry run has nothing to report a target as.
    REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)"
  fi
  REPO="${REPO:-<unknown - set REPO=owner/name>}"
fi

if [[ "$DRY_RUN" -eq 0 && "$REPO" == "<unknown"* ]]; then
  echo "ERROR: could not determine the target repository. Run from a checkout" >&2
  echo "       with 'gh auth login' done, or pass REPO=owner/name." >&2
  exit 1
fi
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
  split_epic "$entry"
  create_label "epic:$EPIC_SLUG" "5319e7" "$EPIC_DESC"
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
