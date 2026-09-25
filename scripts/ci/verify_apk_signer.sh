#!/usr/bin/env bash
# Assert that an APK is signed, and signed by something other than the Android
# debug key.
#
#   scripts/ci/verify_apk_signer.sh <path/to.apk>
#
# Exit 0 only when ALL of the following hold:
#   1. apksigner verifies the APK (a certificate can be read at all);
#   2. it reports "Number of signers:" with a count of at least 1;
#   3. at least one certificate DN is printed;
#   4. no printed DN is the Android debug identity (CN=Android Debug).
#
# Why this file exists instead of an inline `run:` block: the guard is a
# pattern match over another tool's human-readable output, and it has shipped
# broken twice in opposite directions - first reading `META-INF/*.RSA`, which a
# v2-signed APK does not contain, so it passed having verified nothing
# (koniz-dev/flutter-starter#62); then greping for `Signer #1 certificate DN:`,
# a label apksigner only emits for v1/JAR signing, so it failed every correctly
# v2-signed build (koniz-dev/flutter-starter#153). As a script it can be pointed
# at a deliberately debug-signed or deliberately unsigned APK and observed to
# fail, which is the only thing that makes it a guard rather than a decoration.
#
# Label vs value: apksigner labels each signer with the scheme that verified it
# - "Signer #1" for v1/JAR, "V2 Signer:", "V3 Signer:", "V3.1 Signer:",
# "Source Stamp Signer" - and the set grows with every new signature scheme.
# Matching the labels means this breaks again the day the toolchain emits a
# scheme nobody listed here. So it matches the *value*: any line carrying
# "certificate DN: <value>", whatever precedes it.
set -euo pipefail

APK="${1:-}"
if [ -z "$APK" ]; then
  echo "::error::usage: $0 <path/to.apk>" >&2
  exit 2
fi
if [ ! -f "$APK" ]; then
  echo "::error::APK not found: $APK" >&2
  exit 1
fi
echo "APK: $APK"

# Explicit override first (used by tests), then the newest build-tools copy.
APKSIGNER="${APKSIGNER:-}"
if [ -z "$APKSIGNER" ]; then
  SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  APKSIGNER="$(ls -1 "$SDK"/build-tools/*/apksigner 2>/dev/null | sort -V | tail -1 || true)"
fi
if [ -z "$APKSIGNER" ] || [ ! -x "$APKSIGNER" ]; then
  echo "::error::apksigner not found under ANDROID_HOME/ANDROID_SDK_ROOT; cannot verify the signer."
  exit 1
fi
echo "Using: $APKSIGNER"

CERTS="$(mktemp)"
trap 'rm -f "$CERTS"' EXIT

# apksigner exits non-zero when the APK does not verify. Capture the status
# instead of letting `set -e` kill the script, so the failure is reported as
# "the certificate is unreadable" rather than as a bare non-zero exit.
rc=0
"$APKSIGNER" verify --print-certs --verbose "$APK" >"$CERTS" 2>&1 || rc=$?
cat "$CERTS"

if [ "$rc" -ne 0 ]; then
  echo "::error::apksigner could not verify $APK (exit $rc): no readable certificate."
  exit 1
fi

# --verbose always prints this line for a verifying APK. Treat it as missing
# rather than as zero if apksigner ever stops printing it: fail closed.
signers="$(sed -n 's/^Number of signers: \([0-9][0-9]*\).*$/\1/p' "$CERTS" | head -1)"
if [ -z "$signers" ]; then
  echo "::error::apksigner printed no 'Number of signers' line; cannot confirm $APK is signed."
  exit 1
fi
if [ "$signers" -lt 1 ]; then
  echo "::error::apksigner reports $signers signers: $APK is unsigned."
  exit 1
fi

dns="$(sed -n 's/^.*certificate DN: \(.*\)$/\1/p' "$CERTS" | sed '/^[[:space:]]*$/d')"
if [ -z "$dns" ]; then
  echo "::error::apksigner printed no certificate DN."
  exit 1
fi

echo "Signers: $signers"
echo "Certificate DN(s):"
printf '%s\n' "$dns" | sed 's/^/  /'

if printf '%s\n' "$dns" | grep -q 'CN=Android Debug'; then
  echo "::error::APK is DEBUG-signed. android/app/build.gradle.kts is supposed to make this impossible."
  exit 1
fi

echo "OK: $APK is signed by $signers non-debug signer(s)."
