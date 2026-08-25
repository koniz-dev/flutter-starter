#!/usr/bin/env bash
# Formats only project Dart sources (not `build/`, `.dart_tool/`, etc.).
# Usage:
#   ./scripts/dev/format_dart.sh              # write changes
#   ./scripts/dev/format_dart.sh --check      # CI-style; exit 1 if reformat needed
#   ./scripts/dev/format_dart.sh --print-paths # echo the scope, for other scripts
#
# `paths` below is the single source of truth for the format scope and must stay
# in step with the "Verify formatting" step in .github/workflows/ci.yml. Anything
# that needs to name the scope should call --print-paths rather than retyping it:
# retyped copies drifted to a wrong value once already (see issue #8).
#
# `bricks` is deliberately NOT in scope: bricks/**/__brick__/** holds Mason
# templates containing mustache, which is not valid Dart, so `dart format` exits
# 65 on it. analysis_options.yaml excludes it for the same reason.
set -euo pipefail
paths=(lib test integration_test tool examples)
if [[ "${1:-}" == "--print-paths" ]]; then
  echo "${paths[*]}"
  exit 0
fi
if [[ "${1:-}" == "--check" ]]; then
  dart format --set-exit-if-changed "${paths[@]}"
else
  dart format "${paths[@]}"
fi
