#!/bin/bash
# Calculate coverage by layer from lcov.info file
# This script extracts coverage percentages for different architectural layers

set -e

# Two output modes, deliberately separated:
#   (default)         human summary, for a developer running this by hand
#   --github-output   ONLY `key=value` lines, safe to append to $GITHUB_OUTPUT
#
# They used to be mixed on stdout, and .github/workflows/coverage.yml appended
# every line with `while IFS='=' read -r key value`, so prose such as
# "Summary of coverage by layer" became a step-output key. See issue #39.
GITHUB_OUTPUT_MODE=0
LCOV_FILE=""
for arg in "$@"; do
  case "$arg" in
    --github-output) GITHUB_OUTPUT_MODE=1 ;;
    -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
    *) LCOV_FILE="$arg" ;;
  esac
done
LCOV_FILE="${LCOV_FILE:-coverage/lcov.info}"

if [ ! -f "$LCOV_FILE" ]; then
  echo "Error: lcov file not found at $LCOV_FILE" >&2
  exit 1
fi

# Function to calculate coverage for a path pattern
calculate_layer_coverage() {
  local pattern=$1

  # Use awk to extract coverage for files matching the pattern
  # Track current file and accumulate coverage data
  awk -v pattern="$pattern" '
    BEGIN {
      total=0
      covered=0
      current_file=""
      file_matches=0
    }

    /^SF:/ {
      # Extract file path (remove SF: prefix)
      current_file = substr($0, 4)
      # Check if file matches pattern
      file_matches = (current_file ~ pattern) ? 1 : 0
      next
    }

    /^DA:/ {
      # Only count if current file matches pattern
      if (file_matches) {
        total++
        # DA format: DA:line_number,execution_count
        split($0, parts, ",")
        if (parts[2] != "0" && parts[2] != "") {
          covered++
        }
      }
      next
    }

    /^end_of_record/ {
      # Reset for next file
      current_file=""
      file_matches=0
      next
    }

    END {
      if (total > 0) {
        printf "%.1f", (covered / total) * 100
      } else {
        printf "0"
      }
    }
  ' "$LCOV_FILE"
}

# Calculate coverage for each layer
# Patterns match file paths containing these segments
DOMAIN_COV=$(calculate_layer_coverage "/features/.*/domain/")
DATA_COV=$(calculate_layer_coverage "/features/.*/data/")
PRESENTATION_COV=$(calculate_layer_coverage "/features/.*/presentation/")
CORE_COV=$(calculate_layer_coverage "/core/")

if [ "$GITHUB_OUTPUT_MODE" -eq 1 ]; then
  # Machine-readable only. Every line here MUST be a valid key=value pair.
  echo "domain=$DOMAIN_COV"
  echo "data=$DATA_COV"
  echo "presentation=$PRESENTATION_COV"
  echo "core=$CORE_COV"
  echo "domain_display=$DOMAIN_COV%"
  echo "data_display=$DATA_COV%"
  echo "presentation_display=$PRESENTATION_COV%"
  echo "core_display=$CORE_COV%"
  exit 0
fi

# Human summary. These are line-coverage percentages, not file counts.
echo "Coverage by layer (percentage of executable lines covered):"
echo "  Domain:       ${DOMAIN_COV}%"
echo "  Data:         ${DATA_COV}%"
echo "  Presentation: ${PRESENTATION_COV}%"
echo "  Core:         ${CORE_COV}%"

