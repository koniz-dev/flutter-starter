#!/bin/bash
# Mutation check for koniz-dev/flutter-starter#367, run from the repo root.
# Each mutant edits api_logging_interceptor.dart, runs the redaction tests and
# test/core/network, records whether anything failed, then restores the file.
set -u
SRC=lib/core/network/interceptors/api_logging_interceptor.dart
TESTS="test/core/network"
run() {
  local name=$1
  if flutter test $TESTS > /dev/null 2>&1; then
    echo "SURVIVED  $name"
  else
    echo "KILLED    $name"
  fi
  git checkout -q -- "$SRC"
}
for rule in password passwd passphrase token secret apikey credential \
            authorization privatekey creditcard cardnumber signature \
            pincode otpcode pin otp cvv cvc session sessionid; do
  # Delete exactly the line `    '<rule>',` inside the two key sets.
  perl -0pi -e "s/(_sensitive(?:KeyFragments|KeysExact) = <String>\{[^}]*?)\n    '$rule',/\$1/s" "$SRC"
  if git diff --quiet -- "$SRC"; then echo "NOT-APPLIED $rule"; continue; fi
  run "remove '$rule'"
done
perl -pi -e "s/'body': _sanitizeBody\(response\.data\)/'body': response.data/" "$SRC"
if git diff --quiet -- "$SRC"; then echo "NOT-APPLIED response"; else run "onResponse logs response.data raw"; fi
