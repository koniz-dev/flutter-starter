#!/usr/bin/env bash
# Formats only project Dart sources (not `build/`, `.dart_tool/`, etc.).
# Usage:
#   ./scripts/dev/format_dart.sh          # write changes
#   ./scripts/dev/format_dart.sh --check # CI-style; exit 1 if reformat needed
set -euo pipefail
paths=(lib test integration_test tool examples)
if [[ "${1:-}" == "--check" ]]; then
  dart format --set-exit-if-changed "${paths[@]}"
else
  dart format "${paths[@]}"
fi
