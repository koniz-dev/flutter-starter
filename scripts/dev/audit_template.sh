#!/usr/bin/env bash
# Non-platform quality gate: env asset guard, format (scoped), analyze,
# unit/widget tests.
# Does not run Android/iOS/Web builds or Patrol E2E.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT"
echo "==> env asset guard"
dart run tool/check_env_assets.dart
echo "==> format ($("$SCRIPT_DIR/format_dart.sh" --print-paths))"
"$SCRIPT_DIR/format_dart.sh" --check
echo "==> flutter analyze"
flutter analyze
echo "==> flutter test"
flutter test "$@"
