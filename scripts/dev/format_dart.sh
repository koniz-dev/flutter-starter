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
# retyped copies drifted to a wrong value once already.
#
# `bricks` is deliberately NOT in scope: bricks/**/__brick__/** holds Mason
# templates containing mustache, which is not valid Dart, so `dart format` exits
# 65 on it. analysis_options.yaml excludes it for the same reason.
set -euo pipefail
# The paths are the project's, wherever this is run from: from a
# subdirectory they named nothing, and --check passed having checked nothing.
SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../.."
if [[ ! -f pubspec.yaml ]]; then
  echo "Error: $PWD is not the project root (no pubspec.yaml). Run" >&2
  echo "scripts/dev/format_dart.sh by its path inside the project." >&2
  exit 1
fi
paths=(lib test integration_test tool examples)
if [[ "${1:-}" == "--print-paths" ]]; then
  echo "${paths[*]}"
  exit 0
fi
if [[ "${1:-}" == "--check" ]]; then
  # --output=none: a check reports, it does not rewrite. Without it `dart
  # format` reformats the tree *and* exits 1.
  dart format --output=none --set-exit-if-changed "${paths[@]}"
else
  dart format "${paths[@]}"
fi
