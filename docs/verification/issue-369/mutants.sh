#!/bin/bash
# Mutation check for koniz-dev/flutter-starter#369, run from the repo root on
# a clean tree. The three mutants from the issue; each is applied, tested,
# then restored with git checkout.
set -u
SRC=lib/core/network/api_client.dart
TESTS=${TESTS:-"test/core/network test/features/auth test/core/di"}
run() {
  local name=$1
  if git diff --quiet -- "$SRC"; then echo "NOT-APPLIED $name"; return; fi
  if flutter test $TESTS > /dev/null 2>&1; then
    echo "SURVIVED  $name"
  else
    echo "KILLED    $name"
  fi
  git checkout -q -- "$SRC"
}
perl -0pi -e 's/(Future<NetworkResponse<dynamic>> _send\(\s*NetworkRequest request,\s*\) async \{)/$1\n    throw UnimplementedError();/' "$SRC"
run "_send throws UnimplementedError first"
perl -0pi -e 's/(Future<NetworkResponse<dynamic>> put\(.*?method: NetworkMethod\.)put/${1}patch/s' "$SRC"
run "put() sends NetworkMethod.patch"
perl -0pi -e 's/(Future<NetworkResponse<dynamic>> delete\(.*?method: NetworkMethod\.)delete/${1}post/s' "$SRC"
run "delete() sends NetworkMethod.post"
