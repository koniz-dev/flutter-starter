#!/usr/bin/env bash
# Evidence probe for koniz-dev/flutter-starter#507, run from the repo root
# with fastlane on PATH.
#
# Copies the tracked tree to a scratch directory and runs each Fastfile build
# lane twice, with `flutter` replaced on PATH by a stub that only prints its
# arguments (so nothing is really built):
#   1. with `- .env` declared under `flutter: assets:` - the guard must fail
#      and the lane must abort before the stub ever prints "FAKE flutter build";
#   2. on the clean tree - the guard passes and the lane reaches the build.
# The lane then fails on the missing artifact, which is expected: the stub
# builds nothing.
#
# Usage: docs/verification/issue-507/lane_abort_probe.sh
set -uo pipefail
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
git ls-files -z | rsync -a --from0 --files-from=- ./ "$WORK/"
mkdir -p "$WORK/.stub-bin"
cat > "$WORK/.stub-bin/flutter" <<'STUB'
#!/usr/bin/env bash
echo "FAKE flutter $*"
STUB
chmod +x "$WORK/.stub-bin/flutter"
(cd "$WORK" && flutter pub get >/dev/null 2>&1)
export PATH="$WORK/.stub-bin:$PATH"
export FASTLANE_SKIP_UPDATE_CHECK=1 FASTLANE_HIDE_TIMESTAMP=1 CI=1

run() { # dir platform lane
  (cd "$WORK/$1" && fastlane "$2" "$3" 2>&1) \
    | sed 's/\x1b\[[0-9;]*m//g' \
    | grep -E "check_env_assets|SECURITY|OK: no|FAKE flutter build|Exit status|not found at|fastlane finished|fastlane.tools finished|Error" \
    | head -8
  echo "exit=${PIPESTATUS[0]}"
}

L=$(grep -n "^  assets:" "$WORK/pubspec.yaml" | cut -d: -f1)
for target in "fastlane android build_apk" "fastlane android build_bundle" \
              "ios/fastlane ios build_adhoc" "ios/fastlane ios build_appstore"; do
  read -r dir platform lane <<<"$target"
  echo "=== $platform $lane, with '- .env' declared"
  cp "$WORK/pubspec.yaml" "$WORK/pubspec.yaml.orig"
  sed -i '' "${L}a\\
    - .env
" "$WORK/pubspec.yaml"
  run "$dir" "$platform" "$lane"
  mv "$WORK/pubspec.yaml.orig" "$WORK/pubspec.yaml"
  echo "=== $platform $lane, clean tree"
  run "$dir" "$platform" "$lane"
  echo
done
