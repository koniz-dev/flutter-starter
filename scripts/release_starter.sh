#!/usr/bin/env bash
# Tags a starter release and publishes its GitHub Release.
#
# Usage: $M/scripts/release_starter.sh vX.Y.Z [--dry-run] [<commit>]
#
# Run from the main checkout. Refuses unless:
#   - origin/main's upgrade guide names this version on its
#     `**Starter version:**` line (what an adopter's copy will say), and
#   - history/starter-changelog.md on this branch has a `## [X.Y.Z]` section,
#     which becomes the release notes verbatim.
# The tag points at <commit> (default: origin/main as fetched), which must be
# on origin/main, so the notes describe exactly what is tagged even if main
# moved after the changelog was written. --dry-run prints the target and the
# notes and changes nothing.
set -euo pipefail

version="${1:-}"
dry_run=""
commit="origin/main"
for arg in "${@:2}"; do
  if [ "$arg" = "--dry-run" ]; then dry_run="$arg"; else commit="$arg"; fi
done
if [[ ! "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage: $0 vX.Y.Z [--dry-run]" >&2
  exit 2
fi
bare="${version#v}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
changelog="$here/history/starter-changelog.md"
guide=docs/guides/migration/upgrading-this-starter.md

git fetch -q origin main --tags
target="$(git rev-parse --verify "$commit^{commit}")"
if ! git merge-base --is-ancestor "$target" origin/main; then
  echo "$commit is not on origin/main." >&2
  exit 1
fi

marker="$(git show "$target:$guide" | grep -m1 '^\*\*Starter version:\*\*' || true)"
if [ "$marker" != "**Starter version:** $version" ]; then
  echo "$commit's $guide says '${marker:-<no marker>}', not '**Starter version:** $version'." >&2
  echo "Merge the marker bump to main first." >&2
  exit 1
fi

notes="$(awk -v h="## [$bare]" '
  index($0, h) == 1 { on = 1; next }
  on && /^## \[/ { exit }
  on { print }
' "$changelog")"
if [ -z "$(printf '%s' "$notes" | tr -d '[:space:]')" ]; then
  echo "$changelog has no '## [$bare]' section, or it is empty." >&2
  exit 1
fi

if git ls-remote --exit-code --tags origin "refs/tags/$version" >/dev/null 2>&1; then
  echo "$version is already tagged on origin." >&2
  exit 1
fi

echo "release $version -> $target"
if [ "$dry_run" = "--dry-run" ]; then
  printf '%s\n' "$notes"
  exit 0
fi

notes_file="$(mktemp)"
trap 'rm -f "$notes_file"' EXIT
printf '%s\n' "$notes" > "$notes_file"
gh release create "$version" --target "$target" --title "$version" \
  --notes-file "$notes_file" --latest
