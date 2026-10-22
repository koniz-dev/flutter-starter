#!/usr/bin/env bash
# Renames a clean copy of REV to my_app (fork-and-customize Option B, steps
# 1-3, including its dart fix), strips it with each variant's flags, and runs flutter analyze.
# Usage: rename_then_strip.sh <repo> <rev> <workdir>
set -uo pipefail
repo=$1; rev=$2; work=$3
for flags in "" "--remove-tasks" "--remove-feature-flags" "--keep-samples"; do
  dir="$work/rts-${flags:-both}"
  rm -rf "$dir"; git -C "$repo" worktree prune
  git -C "$repo" worktree add -q --detach "$dir" "$rev"
  (
    cd "$dir"
    echo "# $(git rev-parse --short HEAD): rename to my_app, then --apply $flags"
    perl -pi -e 's/^name: flutter_starter$/name: my_app/' pubspec.yaml
    git grep -lz 'package:flutter_starter/' -- lib test integration_test tool \
      examples bricks/feature_clean scripts/dev/create_feature.sh \
      scripts/dev/create_feature.ps1 'docs/*.dart' \
      | xargs -0 perl -pi -e 's#package:flutter_starter/#package:my_app/#g'
    # Step 3 of Option B: re-sort imports for the new package name.
    flutter pub get >/dev/null 2>&1
    dart fix --apply --code=directives_ordering >/dev/null 2>&1
    flutter analyze >/dev/null 2>&1 && echo 'renamed tree (before strip): analyze clean'
    dart run tool/strip_sample_features.dart --apply $flags 2>&1 | tail -2
    flutter pub get >/dev/null 2>&1
    flutter analyze 2>&1 | grep -E "^ *(info|warning|error) |issues? found"
    echo "analyze exit: ${PIPESTATUS[0]}"
    echo
  )
  git -C "$repo" worktree remove --force "$dir"
done
