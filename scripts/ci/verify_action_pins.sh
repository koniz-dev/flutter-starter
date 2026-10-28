#!/usr/bin/env bash
# Verifies that every pinned action's SHA is the commit its version comment
# names.
#
# `tool/check_action_pins.dart` proves each `uses` is pinned as
# `owner/repo@<40-hex sha> # vX.Y.Z`, but not that the SHA belongs to that
# release. GitHub resolves `owner/repo@<sha>` for any commit in the
# repository's fork network, including one pushed only to a fork, so a pin
# that reads like a routine Dependabot bump can still run someone else's code.
# This resolves each `# vX.Y.Z` tag in `owner/repo` through the GitHub API,
# peeling annotated tags, and fails when the commit differs from the pin.
#
# Usage:
#   scripts/ci/verify_action_pins.sh [file...]
#
# With no arguments it reads every workflow under `.github/workflows/` and
# every `action.yml` / `action.yaml` under `.github/`, relative to the current
# directory. Needs `gh` authenticated (in Actions:
# `GH_TOKEN: ${{ github.token }}`).
#
# Exits 0 when every pin matches its tag, 1 when one does not (or its tag does
# not exist), 2 when the API could not be asked.
set -euo pipefail

if [ "$#" -gt 0 ]; then
  files=("$@")
else
  files=()
  while IFS= read -r f; do files+=("$f"); done < <(
    find .github -type f \( -path '.github/workflows/*.yml' \
      -o -path '.github/workflows/*.yaml' \
      -o -name action.yml -o -name action.yaml \) | sort
  )
fi
if [ "${#files[@]}" -eq 0 ]; then
  echo "No workflows found under .github/." >&2
  exit 2
fi

# A pin anywhere on a line. The offline check already guarantees every `uses`
# is in this form, however its key is spelled, so the line is enough.
pin_re='([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)[A-Za-z0-9_./-]*@([0-9a-f]{40})[^#]*#[[:space:]]*(v?[0-9]+(\.[0-9]+){1,2}[^[:space:]]*)'

# Prints "<type> <sha>" for a git object reference; prints nothing for a 404.
git_object() {
  local out
  if ! out="$(gh api "$1" --jq '.object.type + " " + .object.sha' 2>&1)"; then
    case "$out" in
      *"HTTP 404"* | *"Not Found"*) return 0 ;;
    esac
    echo "GitHub API error for $1: $out" >&2
    exit 2
  fi
  printf '%s\n' "$out"
}

# The commit `tag` names in `repo`, following annotated tags to their target;
# nothing when the tag does not exist.
tag_commit() {
  local repo="$1" tag="$2" object type sha
  # git_object runs in a subshell here, so pass its exit 2 on.
  object="$(git_object "repos/$repo/git/ref/tags/$tag")" || exit $?
  read -r type sha <<< "$object"
  while [ "${type:-}" = tag ]; do
    object="$(git_object "repos/$repo/git/tags/$sha")" || exit $?
    read -r type sha <<< "$object"
  done
  if [ "${type:-}" = commit ]; then printf '%s\n' "$sha"; fi
}

# One API lookup per repo@tag; bash 3.2 (macOS) has no associative arrays.
cache="$(mktemp -d)"
trap 'rm -rf "$cache"' EXIT
checked=0
failed=0
for file in "${files[@]}"; do
  n=0
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    [[ "$line" =~ $pin_re ]] || continue
    repo="${BASH_REMATCH[1]}" sha="${BASH_REMATCH[2]}" tag="${BASH_REMATCH[3]}"
    entry="$cache/${repo//\//__}@$tag"
    [ -f "$entry" ] || tag_commit "$repo" "$tag" > "$entry"
    real="$(cat "$entry")"
    checked=$((checked + 1))
    if [ -z "$real" ]; then
      echo "$file:$n: $repo has no tag $tag; the pin is $sha" >&2
      failed=$((failed + 1))
    elif [ "$real" != "$sha" ]; then
      echo "$file:$n: $repo $tag is $real, but the pin is $sha" >&2
      failed=$((failed + 1))
    fi
  done < "$file"
done

if [ "$failed" -gt 0 ]; then
  echo "$failed of $checked pins are not the commit their version comment names." >&2
  exit 1
fi
echo "$checked pins in ${#files[@]} files match their version comment."
