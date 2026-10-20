#!/usr/bin/env bash
# Replay captured apksigner transcripts through scripts/ci/verify_apk_signer.sh.
#
#   docs/verification/issue-153/replay/replay.sh
#
# Why this exists: the CI runs linked from koniz-dev/flutter-starter#153 prove
# the guard on three real APKs (v2-signed release, debug-signed, unsigned).
# They cannot reach the branches that depend on apksigner printing something
# this project has never emitted - a v1/JAR label, a v3 label, a zero signer
# count, a missing DN. `bin/apksigner` is a stub that replays a recorded
# transcript, so those branches are exercised too.
#
# `fixtures/v2-only.txt` is the verbatim output of build-tools 37.0.0 in run
# 36136950123; the rest are hand-written in the same format.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${1:-$(cd "$HERE/../../../.." && pwd)}"
GUARD="$ROOT/scripts/ci/verify_apk_signer.sh"
TMPAPK="$(mktemp -t stub-apk)"
fails=0

run() {
  local name="$1" fixture="$2" want="$3" rc_stub="${4:-0}"
  echo "=============================================================="
  echo "case: $name"
  echo "  fixture: $fixture, stub apksigner exits $rc_stub, guard expected to exit $want"
  echo "--------------------------------------------------------------"
  FIXTURE="$HERE/fixtures/$fixture" FIXTURE_RC="$rc_stub" APKSIGNER="$HERE/bin/apksigner" \
    bash "$GUARD" "$TMPAPK"
  local got=$?
  if [ "$got" -eq "$want" ]; then
    echo "--> exit $got: as expected"
  else
    echo "--> exit $got: UNEXPECTED (wanted $want)"
    fails=$((fails + 1))
  fi
  echo
}

# Accepted: every scheme label apksigner can put in front of "certificate DN:".
run "v2-only release APK (verbatim output of run 36136950123)" v2-only.txt 0
run "v1/JAR-signed APK ('Signer #1' label)" v1-only.txt 0
run "v3 + v3.1 signed APK ('V3 Signer:' / 'V3.1 Signer:' labels)" v3.txt 0

# Rejected.
run "debug-signed APK" debug.txt 1
run "unsigned APK (apksigner itself exits 1)" unsigned.txt 1 1
run "verifies, but 'Number of signers: 0'" zero-signers.txt 1
run "verifies, but no certificate DN printed" no-dn.txt 1
run "verifies, but no 'Number of signers' line at all" no-count.txt 1

rm -f "$TMPAPK"
echo "=============================================================="
if [ "$fails" -eq 0 ]; then
  echo "all 8 cases behaved as expected"
else
  echo "$fails case(s) misbehaved"
fi
exit "$fails"
