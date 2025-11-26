#!/bin/bash
# Calculate coverage by layer from lcov.info file
# This script extracts coverage percentages for different architectural layers

set -e

LCOV_FILE="${1:-coverage/lcov.info}"

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

# Output values with % suffix for display
echo "Output values with % suffix for display"
echo "domain_display=$DOMAIN_COV%"
echo "data_display=$DATA_COV%"
echo "presentation_display=$PRESENTATION_COV%"
echo "core_display=$CORE_COV%"

# Output numeric values for comparison
echo "Output numeric values for comparison"
echo "domain=$DOMAIN_COV"
echo "data=$DATA_COV"
echo "presentation=$PRESENTATION_COV"
echo "core=$CORE_COV"

# Print to console for visibility
echo "Summary of coverage by layer"
echo "Domain Layer: ${DOMAIN_COV}%"
echo "Data Layer: ${DATA_COV}%"
echo "Presentation Layer: ${PRESENTATION_COV}%"
echo "Core Layer: ${CORE_COV}%"
