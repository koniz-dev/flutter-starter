#!/bin/bash
# Mutation check for koniz-dev/flutter-starter#353, run from the repo root.
# Each mutant edits one file, runs the session-reset test, records whether
# anything failed, then restores the file.
set -u
T=test/features/tasks/presentation/providers/tasks_session_reset_test.dart
P=lib/features/tasks/presentation/providers/tasks_provider.dart
R=lib/features/tasks/routing/tasks_routes.dart
run() {
  local name=$1 file=$2
  if git diff --quiet -- "$file"; then echo "NOT-APPLIED $name"; return; fi
  if flutter test "$T" > /dev/null 2>&1; then
    echo "SURVIVED  $name"
  else
    echo "KILLED    $name"
  fi
  git checkout -q -- "$file"
}
# 1. The routes no longer start the reset at startup.
perl -pi -e 's/^  ref\.read\(tasksSessionResetProvider\);\n//' "$R"
run "routes do not read tasksSessionResetProvider" "$R"
# 2. Only the in-memory state is reset; the stored blob survives.
perl -0pi -e 's/final pendingDelete = ref\s*\.read\(tasksLocalDataSourceProvider\)\s*\.deleteAllTasks\(\);/final pendingDelete = Future<void>.value();/' "$P"
run "reset skips deleteAllTasks()" "$P"
# 3. Invalidate first, delete after: the rebuilt notifier can reload A's tasks.
perl -0pi -e 's/final pendingDelete = (ref\s*\.read\(tasksLocalDataSourceProvider\)\s*\.deleteAllTasks\(\));\s*unawaited\(\s*pendingDelete\.whenComplete\(\(\) \{\s*if \(ref\.mounted\) ref\.invalidate\(tasksProvider\);\s*\}\),\s*\);/ref.invalidate(tasksProvider);\n    unawaited($1);/s' "$P"
run "invalidate before the delete completes" "$P"
