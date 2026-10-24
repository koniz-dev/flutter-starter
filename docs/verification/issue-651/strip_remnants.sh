#!/usr/bin/env bash
# Applies each strip variant to a clean copy of REV and looks for what the
# removed sample left behind: the task UiKeys and an unread
# ENABLE_DEBUG_FEATURES. Then analyze and test the stripped tree.
set -uo pipefail
repo=$1; rev=$2; work=$3
for flags in "" "--remove-tasks" "--remove-feature-flags"; do
  dir="$work/sr-${flags:-both}"
  rm -rf "$dir"; git -C "$repo" worktree prune
  git -C "$repo" worktree add -q --detach "$dir" "$rev"
  (
    cd "$dir"
    echo "# $(git rev-parse --short HEAD): --apply $flags"
    flutter pub get >/dev/null 2>&1
    dart run tool/strip_sample_features.dart --apply $flags 2>&1 | tail -1
    flutter pub get >/dev/null 2>&1
    echo "task UiKeys left: $(git grep -c -e openTasks -e tasksFab -e addTaskSubmit -- lib | wc -l | tr -d ' ') file(s)"
    echo "readers of AppConfig.enableDebugFeatures outside lib/core/config:"
    git grep -l 'AppConfig.enableDebugFeatures' -- lib ':!lib/core/config' | sed 's/^/  /'
    flutter analyze 2>&1 | tail -1
    flutter test --timeout=5m 2>&1 | tail -1
    echo
  )
  git -C "$repo" worktree remove --force "$dir"
done
