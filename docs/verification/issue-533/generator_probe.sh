#!/usr/bin/env bash
# Evidence probe for koniz-dev/flutter-starter#533, run from the repo root with
# mason on PATH. GUARD names a copy of #515's guard test
# (test/tooling/text_literal_guard_test.dart) to run against the output.
#
# In a scratch copy of the tracked tree: generates a `profile` slice with
# create_feature.sh and with `mason make feature_clean`, then for each runs
# flutter analyze on the slice and the Text( literal guard, and finally diffs
# the two generated screens.
#
# Usage: GUARD=path/to/text_literal_guard_test.dart docs/verification/issue-533/generator_probe.sh
set -uo pipefail
: "${GUARD:?set GUARD to the guard test file}"
ROOT="$PWD"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
gen() { # name
  local work
  work="$(mktemp -d)"
  git -C "$ROOT" ls-files -z | rsync -a --from0 --files-from=- "$ROOT/" "$work/"
  cp "$GUARD" "$work/test/tooling/text_literal_guard_test.dart"
  (cd "$work" && flutter pub get >/dev/null 2>&1)
  case "$1" in
    sh) (cd "$work" && ./scripts/dev/create_feature.sh profile >/dev/null) ;;
    mason) (cd "$work" && mason get >/dev/null 2>&1 &&
      mason make feature_clean --feature_name profile --class_name Profile --include_tests false -o . --on-conflict overwrite >/dev/null 2>&1) ;;
  esac
  echo "$work"
}
for tool in sh mason; do
  dir=$(gen "$tool")
  echo "=== $tool: lib/features/profile/presentation/screens/profile_screen.dart"
  grep -n "Text(\|l10n-literal-ok\|localization_extensions" \
    "$dir/lib/features/profile/presentation/screens/profile_screen.dart"
  echo "--- flutter analyze lib/features/profile"
  (cd "$dir" && flutter analyze lib/features/profile 2>&1 | tail -1)
  echo "--- text_literal_guard_test.dart"
  (cd "$dir" && flutter test test/tooling/text_literal_guard_test.dart 2>&1 \
    | tr '\r' '\n' | grep -a "All tests\|Some tests\|profile_screen" | tail -3)
  cp "$dir/lib/features/profile/presentation/screens/profile_screen.dart" "$OUT/$tool.dart"
  rm -rf "$dir"
  echo
done
echo "=== diff create_feature.sh vs feature_clean screen (empty = identical)"
diff "$OUT/sh.dart" "$OUT/mason.dart" && echo "(identical)"
