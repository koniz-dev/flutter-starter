#!/usr/bin/env bash
# Points this repository's git hooks at .githooks/ (core.hooksPath).
#
# The hooks used to be copied into .git/hooks/, which git ignores whenever
# core.hooksPath is set (a global setting, a husky-style setup): the script
# printed "installed" and nothing ever ran. Copies also went stale - a fix to
# .githooks/ never reached an existing clone. Pointing core.hooksPath at the
# tracked directory runs the current hooks, in every worktree, and running
# this twice changes nothing.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "❌ Not inside a Git repository: $ROOT"
  exit 1
fi

for name in pre-commit commit-msg pre-push; do
  if [ ! -x ".githooks/$name" ]; then
    echo "❌ Required hook missing or not executable: .githooks/$name"
    exit 1
  fi
done

# A relative core.hooksPath is read from the top of the working tree, not
# from here. With the app in a subdirectory of a larger repository (a
# monorepo), a bare `.githooks` named a directory that does not exist there,
# so no hook ran at all. Prefix it with this directory's path from the top.
hooks_path="$(git rev-parse --show-prefix).githooks"

# A repository-local hooksPath somebody chose is theirs: say so, do not
# overwrite it. A bare `.githooks` is this script's own (an earlier version
# wrote it, even in a monorepo, where it named nothing), so it is replaced.
# A global one is overridden for this repository only.
local_path="$(git config --local --get core.hooksPath || true)"
if [ -n "$local_path" ] && [ "$local_path" != "$hooks_path" ] && [ "$local_path" != ".githooks" ]; then
  echo "❌ This repository already sets core.hooksPath to '$local_path',"
  echo "   so git runs the hooks there, not .githooks/. Either:"
  echo "     git config --local core.hooksPath '$hooks_path'   # use this repo's hooks"
  echo "   or call .githooks/* from your own hooks in '$local_path'."
  exit 1
fi
global_path="$(git config --global --get core.hooksPath || true)"

# Hooks already in the repository's own hooks directory stop running once
# core.hooksPath points elsewhere. Name the ones .githooks/ does not replace,
# so nobody loses a post-checkout or pre-rebase hook without knowing.
common_hooks="$(git rev-parse --git-common-dir)/hooks"
orphaned=()
if [ -d "$common_hooks" ]; then
  for hook in "$common_hooks"/*; do
    [ -f "$hook" ] && [ -x "$hook" ] || continue
    name="$(basename "$hook")"
    case "$name" in *.sample) continue ;; esac
    [ -e ".githooks/$name" ] && continue
    orphaned+=("$name")
  done
fi

git config --local core.hooksPath "$hooks_path"

# Verify with git itself: this is the directory it will run hooks from
# (printed relative to this directory). On a mismatch, put the previous
# setting back rather than leave one that runs no hook.
resolved="$(git rev-parse --git-path hooks)"
if [ "$resolved" != ".githooks" ]; then
  if [ -n "$local_path" ]; then
    git config --local core.hooksPath "$local_path"
  else
    git config --local --unset core.hooksPath
  fi
  echo "❌ git still resolves hooks to '$resolved', not .githooks/."
  echo "   core.hooksPath was restored to what it was before."
  exit 1
fi

echo "✅ Git hooks active: core.hooksPath = $hooks_path"
if [ -n "$global_path" ]; then
  echo "   (overrides your global core.hooksPath '$global_path' for this repository)"
fi
if [ "${#orphaned[@]}" -gt 0 ]; then
  echo "⚠️  These hooks in $common_hooks will no longer run, because"
  echo "   git now reads .githooks/ instead: ${orphaned[*]}"
  echo "   Move them into .githooks/ (or call them from there) to keep them."
fi
echo "   pre-commit  → dart format (scoped) + flutter analyze"
echo "   commit-msg  → Conventional Commits"
echo "   pre-push    → flutter test (compact, timeout)"
echo ""
echo "Skip when needed: git commit --no-verify  |  git push --no-verify"
