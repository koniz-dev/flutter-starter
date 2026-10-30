#!/bin/bash
# Usage: fastlane_pinning_probe.sh <git-ref> <out-log>
# Runs the real Fastfile lanes in a scratch clone with a stub flutter that logs
# its arguments and writes an empty artifact, and no store credentials.
set -u
REF="$1"; OUT="$2"
W=$(mktemp -d)
git clone -q file:///Users/nguyenanhkiet/Playground/flutter-starter "$W/repo" && git -C "$W/repo" checkout -q "$REF"
mkdir -p "$W/bin"
cat > "$W/bin/flutter" <<'STUB'
#!/bin/bash
echo "flutter $*" >> "$FLUTTER_LOG"
case "$1 $2" in
  "build appbundle") mkdir -p build/app/outputs/bundle/release && : > build/app/outputs/bundle/release/app-release.aab ;;
  "build apk") mkdir -p build/app/outputs/flutter-apk && : > build/app/outputs/flutter-apk/app-release.apk ;;
  "build ipa") mkdir -p build/ios/ipa && : > build/ios/ipa/Runner.ipa ;;
esac
exit 0
STUB
printf '#!/bin/bash\nexit 0\n' > "$W/bin/dart"
chmod +x "$W/bin/flutter" "$W/bin/dart"
export PATH="$W/bin:/Users/nguyenanhkiet/.local/share/gem/ruby/4.0.0/bin:$PATH" FASTLANE_SKIP_UPDATE_CHECK=1 FASTLANE_HIDE_CHANGELOG=1 FASTLANE_DISABLE_COLORS=1 CI=1
unset API_SSL_FINGERPRINTS ENABLE_SSL_PINNING
FP=$(printf 'ab%.0s' $(seq 32))
run() { # <label> <dir> <env...> -- <fastlane args...>
  local label="$1" dir="$2"; shift 2
  local envs=(); while [ "$1" != "--" ]; do envs+=("$1"); shift; done; shift
  export FLUTTER_LOG="$W/flutter-$RANDOM.log"; : > "$FLUTTER_LOG"
  echo "== $label: ${envs[*]:-} fastlane $*"
  (cd "$W/repo/$dir" && env ${envs[@]+"${envs[@]}"} fastlane "$@" 2>&1 | grep -E "^\[!\]|API_SSL_FINGERPRINTS|ssl_pinning" | grep -v "^\[.*\]: \$" | head -3)
  echo "   flutter calls:"; sed 's/^/     /' "$FLUTTER_LOG"; [ -s "$FLUTTER_LOG" ] || echo "     (none)"
}
{
  echo "== ref $REF ($(git -C "$W/repo" rev-parse --short HEAD))"
  run "android, no fingerprints" . -- android build_bundle environment:production
  run "android, env fingerprints" . "API_SSL_FINGERPRINTS=$FP" -- android build_bundle environment:production
  run "android, option forwarded by upload_internal" . -- android upload_internal environment:staging "ssl_fingerprints:$FP"
  run "android, opt-out option" . -- android build_apk environment:production ssl_pinning:false
  run "android, bad fingerprint" . "API_SSL_FINGERPRINTS=AA:BB" -- android build_bundle environment:production
  run "ios, no fingerprints" ios -- ios build_appstore environment:production
  run "ios, option forwarded by upload_testflight" ios -- ios upload_testflight environment:staging "ssl_fingerprints:$FP"
  run "ios, adhoc opt-out env" ios "ENABLE_SSL_PINNING=false" -- ios build_adhoc environment:staging
} > "$OUT" 2>&1
rm -rf "$W"
