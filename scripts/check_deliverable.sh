#!/usr/bin/env bash
# The deliverable gate: main is what an adopter gets from "Use this template",
# so nothing on it may exist only to run this repository's issue loop
# (koniz-dev/flutter-starter#621).
#
# Run from a checkout of main (or pass a ref):
#   $M/scripts/check_deliverable.sh              # checks origin/main
#   $M/scripts/check_deliverable.sh HEAD         # checks the current commit
#
# Fails, listing every hit, when the tree at REF
#   * contains a path that belongs to the upstream process (evidence, the issue
#     workflow, agent roles, the label taxonomy, the Refs check), or
#   * names that process in a tracked file: status/priority/epic labels, the
#     needs-uat state, the issue workflow, the acceptance harness, or the
#     process-only strip.
# Provenance such as "koniz-dev/flutter-starter#123" is allowed: an adopter can
# follow it, and it explains why the code is the way it is.
set -euo pipefail

REF="${1:-origin/main}"
git rev-parse --verify --quiet "$REF^{commit}" >/dev/null || {
  echo "Not a commit: $REF (run from a checkout of main)." >&2
  exit 2
}

# Paths that must not exist on main.
forbidden_paths=(
  docs/verification
  docs/issue-workflow.md
  docs/architecture/migrations
  docs/guides/support/mason-demo-script.md
  .claude/agents
  scripts/bootstrap-issue-labels.sh
  scripts/dev/check_issue_refs.sh
  scripts/test/run_acceptance.sh
  .github/workflows/issue-refs.yml
  tool/check_epic_coverage.dart
  test/tooling/epic_coverage_test.dart
)

# Upstream-process vocabulary that must not appear in main's files.
vocabulary='status:(todo|in-progress|blocked|needs-uat)|priority:P[0-3]|epic:[a-z]|needs-uat|issue-workflow|\.claude/agents|process-only|run_acceptance|bootstrap-issue-labels|check_issue_refs|issue-refs\.yml|epic_coverage'

status=0

for path in "${forbidden_paths[@]}"; do
  if [[ -n "$(git ls-tree --name-only "$REF" -- "$path")" ]]; then
    echo "upstream-only path on $REF: $path"
    status=1
  fi
done

if hits=$(git grep -n -I -E "$vocabulary" "$REF" -- . 2>/dev/null); then
  echo "$hits" | sed "s#^$REF:#upstream process named in #"
  status=1
fi

if [[ $status -eq 0 ]]; then
  echo "Deliverable: $REF carries nothing that only serves the upstream process."
else
  echo
  echo "Move these to the maintainers branch, or reword them for an adopter."
fi
exit $status
