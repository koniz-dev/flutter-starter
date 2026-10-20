#!/usr/bin/env bash
# Set up a checkout of the starter for maintainer work. Run from the main
# checkout:
#
#   git fetch origin maintainers evidence
#   git worktree add ../flutter-starter-maintainers origin/maintainers
#   ../flutter-starter-maintainers/scripts/install.sh
#
# It
#   * creates the evidence worktree ($E, ../flutter-starter-evidence) if absent,
#   * links agents/*.md into the checkout's .claude/agents/ so Claude Code finds
#     the planner, implementer, qa and security roles,
#   * writes the checkout's CLAUDE.local.md, which imports process.md, so a
#     session loads the maintainer process next to main's CLAUDE.md, and
#   * keeps both out of git through .git/info/exclude.
# Nothing it writes is tracked, so main stays what an adopter receives
# (koniz-dev/flutter-starter#620). Safe to re-run.
set -euo pipefail

MAINT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Run this from the main checkout." >&2
  exit 2
}
[[ -f "$ROOT/pubspec.yaml" ]] || {
  echo "$ROOT has no pubspec.yaml; run this from the main checkout." >&2
  exit 2
}
if [[ -n "$(git -C "$ROOT" ls-files .claude/agents)" ]]; then
  echo ".claude/agents is still tracked in $ROOT; update main first." >&2
  exit 2
fi

EVIDENCE="${EVIDENCE_DIR:-$(cd "$ROOT/.." && pwd)/flutter-starter-evidence}"
if [[ ! -d "$EVIDENCE/docs/verification" ]]; then
  git -C "$ROOT" fetch -q origin evidence
  git -C "$ROOT" worktree add -q --detach "$EVIDENCE" origin/evidence
  echo "Created the evidence worktree at $EVIDENCE"
fi

mkdir -p "$ROOT/.claude/agents"
for role in "$MAINT"/agents/*.md; do
  ln -sfn "$role" "$ROOT/.claude/agents/$(basename "$role")"
done

cat >"$ROOT/CLAUDE.local.md" <<EOF
<!-- Written by $MAINT/scripts/install.sh. Untracked; re-run it to refresh. -->
This checkout is the upstream starter (koniz-dev/flutter-starter). Besides
CLAUDE.md, follow the maintainer process below.

- \$M (maintainers worktree): $MAINT
- \$E (evidence worktree): $EVIDENCE

@$MAINT/process.md
EOF

EXCLUDE="$(git -C "$ROOT" rev-parse --git-common-dir)/info/exclude"
mkdir -p "$(dirname "$EXCLUDE")"
touch "$EXCLUDE"
for pattern in /CLAUDE.local.md /.claude/agents/; do
  grep -qxF "$pattern" "$EXCLUDE" || echo "$pattern" >>"$EXCLUDE"
done

echo "Maintainer setup done for $ROOT:"
echo "  CLAUDE.local.md -> @$MAINT/process.md"
echo "  .claude/agents/ -> $MAINT/agents/"
echo "  evidence        -> $EVIDENCE"
