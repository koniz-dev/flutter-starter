#!/bin/bash
# Usage: fastlane_probe.sh <git-ref> <out-log>
# Runs the real upload lanes of both Fastfiles in a scratch clone, with stub
# flutter/dart that write an empty artifact, and no store credentials. Shows
# whether the upload action accepts the artifact path (it then fails later,
# on credentials) or rejects it ("Could not find ... file").
set -u
REF="$1"; OUT="$2"
W=$(mktemp -d)
git clone -q --depth 1 --branch "$REF" file:///Users/nguyenanhkiet/Playground/flutter-starter "$W/repo" 2>/dev/null || { git clone -q file:///Users/nguyenanhkiet/Playground/flutter-starter "$W/repo"; git -C "$W/repo" checkout -q "$REF"; }
mkdir -p "$W/bin"
cat > "$W/bin/flutter" <<'STUB'
#!/bin/bash
case "$1 $2" in
  "build appbundle") mkdir -p build/app/outputs/bundle/release && : > build/app/outputs/bundle/release/app-release.aab ;;
  "build ipa") mkdir -p build/ios/ipa && : > build/ios/ipa/Runner.ipa ;;
esac
exit 0
STUB
printf '#!/bin/bash\nexit 0\n' > "$W/bin/dart"
chmod +x "$W/bin/flutter" "$W/bin/dart"
export PATH="$W/bin:/Users/nguyenanhkiet/.local/share/gem/ruby/4.0.0/bin:$PATH" FASTLANE_SKIP_UPDATE_CHECK=1 FASTLANE_HIDE_CHANGELOG=1 FASTLANE_DISABLE_COLORS=1 CI=1 API_SSL_FINGERPRINTS=$(printf 'ab%.0s' $(seq 32))
{
  echo "== ref $REF ($(git -C "$W/repo" rev-parse --short HEAD))"
  echo "== android: fastlane android upload_internal"
  (cd "$W/repo" && fastlane android upload_internal 2>&1 | grep -v "^\tfrom " | tail -15)
  echo "== ios: (cd ios && fastlane ios upload_testflight)"
  (cd "$W/repo/ios" && fastlane ios upload_testflight 2>&1 | tail -15)
} > "$OUT" 2>&1
rm -rf "$W"
