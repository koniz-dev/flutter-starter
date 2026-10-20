#!/bin/bash
# Mutation check for koniz-dev/flutter-starter#368, run from the repo root.
# Deletes sessionGeneration.invalidate() from login() or register() alone,
# runs test/core and test/features/auth, records whether anything failed,
# then restores the file.
set -u
SRC=lib/features/auth/data/repositories/auth_repository_impl.dart
for method in login register; do
  perl -0pi -e "s/(Future<Result<User>> $method\([^{]*\{.*?)\n    sessionGeneration\.invalidate\(\);/\$1/s" "$SRC"
  if git diff --quiet -- "$SRC"; then echo "NOT-APPLIED $method"; continue; fi
  echo "--- mutant diff ($method)"; git diff -U0 -- "$SRC" | grep '^[-+] '
  if flutter test test/core test/features/auth > /dev/null 2>&1; then
    echo "SURVIVED  delete invalidate() from $method()"
  else
    echo "KILLED    delete invalidate() from $method()"
  fi
  git checkout -q -- "$SRC"
done
