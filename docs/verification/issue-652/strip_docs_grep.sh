#!/usr/bin/env bash
# Applies each strip variant to a clean copy of REV and greps the kept docs
# for the files and samples that variant deleted; check_docs must pass too.
set -uo pipefail
repo=$1; rev=$2; work=$3
for flags in "" "--remove-tasks" "--remove-feature-flags"; do
  dir="$work/sd-${flags:-both}"
  rm -rf "$dir"; git -C "$repo" worktree prune
  git -C "$repo" worktree add -q --detach "$dir" "$rev"
  (
    cd "$dir"
    flutter pub get >/dev/null 2>&1
    dart run tool/strip_sample_features.dart --apply $flags >/dev/null 2>&1
    case "$flags" in
      --remove-tasks) pat='features/tasks\|tasks sample' ;;
      --remove-feature-flags) pat='features/feature_flags\|feature.flags sample' ;;
      *) pat='features/tasks\|features/feature_flags\|tasks sample\|feature.flags sample' ;;
    esac
    echo "# $(git rev-parse --short HEAD): --apply $flags"
    echo "\$ git grep -n -i '$pat' -- docs"
    git grep -n -i "$pat" -- docs | cut -c1-160
    echo "matches: $(git grep -c -i "$pat" -- docs | awk -F: '{s+=$2} END{print s+0}')"
    dart run tool/check_docs.dart 2>&1 | tail -1
    echo
  )
  git -C "$repo" worktree remove --force "$dir"
done
