#!/usr/bin/env bash
# Non-platform quality gate: format (scoped), analyze, unit/widget tests.
# Does not run Android/iOS/Web builds or Patrol E2E.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT"
echo "==> format (lib test integration_test tool bricks)"
"$SCRIPT_DIR/format_dart.sh" --check
echo "==> flutter analyze"
flutter analyze
echo "==> flutter test"
flutter test "$@"
