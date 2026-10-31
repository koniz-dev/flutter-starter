#!/bin/bash

# Test coverage script
# Usage: ./scripts/test/test_coverage.sh [options]
# Options:
#   --html          Generate HTML coverage report
#   --open          Open HTML report after generation
#   --min=<percent> Set minimum coverage threshold (default: 80)
#   --exclude=<path> Exclude path from coverage (can be used multiple times)
#   --analyze       Analyze coverage by layer and identify gaps
#   --no-test       Skip running tests (use existing coverage/lcov.info)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
GENERATE_HTML=false
OPEN_HTML=false
MIN_COVERAGE=80
EXCLUDE_PATHS=()
ANALYZE_COVERAGE=false
SKIP_TEST=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --html)
      GENERATE_HTML=true
      shift
      ;;
    --open)
      OPEN_HTML=true
      GENERATE_HTML=true
      shift
      ;;
    --min=*)
      MIN_COVERAGE="${1#*=}"
      shift
      ;;
    --exclude=*)
      EXCLUDE_PATHS+=("${1#*=}")
      shift
      ;;
    --analyze)
      ANALYZE_COVERAGE=true
      shift
      ;;
    --no-test)
      SKIP_TEST=true
      shift
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Usage: ./scripts/test/test_coverage.sh [--html] [--open] [--min=<percent>] [--exclude=<path>] [--analyze] [--no-test]"
      exit 1
      ;;
  esac
done

# A percentage, e.g. 80 or 79.5. Anything else is refused before it reaches a
# comparison.
is_percent() {
  [[ "$1" =~ ^[0-9]+(\.[0-9]+)?$ ]]
}

# Whether percentage $1 is below $2. In awk rather than bc: bash compares
# only integers, and with bc missing `(( $(echo ... | bc -l) ))` is an empty
# (( )), which is false, so a failing coverage read as a pass.
below() {
  awk -v a="$1" -v b="$2" 'BEGIN { exit !(a + 0 < b + 0) }'
}

if ! is_percent "$MIN_COVERAGE"; then
  echo -e "${RED}--min must be a number (e.g. --min=80), got '${MIN_COVERAGE}'${NC}"
  exit 1
fi

# Run tests with coverage (unless skipped)
if [ "$SKIP_TEST" = false ]; then
echo -e "${BLUE}Running tests with coverage...${NC}"
echo ""
# Imports every library under lib/, so a file no test loads still appears in
# lcov.info (with zero hits) instead of being left out of the total.
# The generated file is removed on any exit: it is git-ignored, so a copy left
# behind went unnoticed until the next rename under lib/ turned its imports
# stale and broke flutter analyze, flutter test and the pre-push hook.
trap 'rm -f test/coverage_helper_test.dart' EXIT
dart run tool/coverage_helper.dart
flutter test --coverage
else
  echo -e "${YELLOW}Skipping tests (using existing coverage data)${NC}"
  echo ""
fi

# Check if lcov.info exists
if [ ! -f "coverage/lcov.info" ]; then
  echo -e "${RED}Error: coverage/lcov.info not found${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Tests completed${NC}"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYER_SCRIPT="$SCRIPT_DIR/calculate_layer_coverage.sh"
FILTERED="coverage/lcov.filtered.info"

# Every number below is computed from a filtered copy of lcov.info, never the
# raw file. The default exclusions are the ones
# .github/workflows/coverage.yml removes before it gates, so a local run and
# CI agree; each --exclude=<path> drops every file whose path contains it.
# `test/**` is anchored there: only the root test/ goes, not a lib/.../test/
# directory, so the same holds here.
# --exclude used to be parsed into EXCLUDE_PATHS and never read.
# Passed through the environment: BSD awk (macOS) rejects a newline inside a
# -v value, and one path per line is the separator a path cannot contain.
COVERAGE_EXCLUDES=$(printf '%s\n' "${EXCLUDE_PATHS[@]}") awk '
  BEGIN { n = split(ENVIRON["COVERAGE_EXCLUDES"], ex, "\n") }
  /^SF:/ {
    path = substr($0, 4)
    skip = (path ~ /\.g\.dart$/ || path ~ /\.freezed\.dart$/ ||
            path ~ /\.config\.dart$/ || path ~ /\/generated\// ||
            path ~ /\/l10n\// || path ~ /(^|\/)main\.dart$/ ||
            path ~ /^test\// || path ~ /_test\.dart$/ ||
            path ~ /(^|\/)test_helpers\.dart$/ ||
            path ~ /(^|\/)test_fixtures\.dart$/)
    for (i = 1; i <= n; i++) {
      if (ex[i] != "" && index(path, ex[i]) > 0) skip = 1
    }
  }
  !skip { print }
  /^end_of_record/ { skip = 0 }
' coverage/lcov.info > "$FILTERED"

# Generate HTML report if requested
if [ "$GENERATE_HTML" = true ]; then
  echo -e "${YELLOW}Generating HTML coverage report...${NC}"

  # Check if lcov is installed
  if ! command -v genhtml &> /dev/null; then
    echo -e "${YELLOW}Warning: genhtml not found. Installing lcov...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
      brew install lcov
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
      sudo apt-get update && sudo apt-get install -y lcov
    else
      echo -e "${RED}Please install lcov manually${NC}"
      exit 1
    fi
  fi

  # Create HTML report directory
  mkdir -p coverage/html

  # Generate HTML report from the same filtered data the numbers use
  genhtml "$FILTERED" -o coverage/html --no-function-coverage

  echo -e "${GREEN}✓ HTML report generated at coverage/html/index.html${NC}"
  echo ""

  # Open HTML report if requested
  if [ "$OPEN_HTML" = true ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
      open coverage/html/index.html
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
      xdg-open coverage/html/index.html 2>/dev/null || echo "Please open coverage/html/index.html manually"
    else
      echo "Please open coverage/html/index.html manually"
    fi
  fi
fi

# Calculate coverage percentage
echo -e "${YELLOW}Calculating coverage...${NC}"

# The same per-record line count CI uses: every file, all layers.
read -r COVERED_LINES TOTAL_LINES <<< "$(bash "$LAYER_SCRIPT" --pattern='.' "$FILTERED")"
if ! [[ "$COVERED_LINES" =~ ^[0-9]+$ && "$TOTAL_LINES" =~ ^[0-9]+$ ]]; then
  # Left unmeasured rather than 0, which a --min=0 run would pass.
  COVERAGE_PERCENT="unmeasured"
elif [ "$TOTAL_LINES" -gt 0 ]; then
  COVERAGE_PERCENT=$(awk "BEGIN {printf \"%.2f\", ($COVERED_LINES / $TOTAL_LINES) * 100}")
else
  COVERAGE_PERCENT=0
fi

echo -e "${BLUE}Coverage Statistics:${NC}"
echo -e "  Total lines: ${TOTAL_LINES}"
echo -e "  Covered lines: ${COVERED_LINES}"
echo -e "  Coverage: ${COVERAGE_PERCENT}%"
echo ""

# Analyze coverage by layer if requested (run before threshold check)
if [ "$ANALYZE_COVERAGE" = true ]; then
  echo ""
  echo -e "${BLUE}=== Coverage Analysis by Layer ===${NC}"
  echo ""

  # Coverage for files whose path matches the regex [pattern], counted by
  # calculate_layer_coverage.sh - the script CI gates on - one lcov record at
  # a time. The old `grep -A 1000` counted the thousand lines after every
  # matching file, so other files spilled into each layer.
  calculate_path_coverage() {
    local pattern=$1
    local name=$2
    local covered_lines total_lines
    read -r covered_lines total_lines <<< "$(bash "$LAYER_SCRIPT" --pattern="$pattern" "$FILTERED")"

    if [ "$total_lines" -gt 0 ]; then
      local percent
      percent=$(awk "BEGIN {printf \"%.1f\", ($covered_lines / $total_lines) * 100}")
      echo -e "${CYAN}$name:${NC} $covered_lines/$total_lines lines ($percent%)"

      # Color code based on coverage
      if ! below "$percent" 80; then
        echo -e "  ${GREEN}✓ Good coverage${NC}"
      elif ! below "$percent" 60; then
        echo -e "  ${YELLOW}⚠ Needs improvement${NC}"
      else
        echo -e "  ${RED}✗ Low coverage${NC}"
      fi
    else
      echo -e "${CYAN}$name:${NC} No coverage data"
    fi
  }

  # Layer patterns match calculate_layer_coverage.sh's own.
  echo -e "${YELLOW}Domain Layer:${NC}"
  calculate_path_coverage "/features/.*/domain/" "  Overall"
  calculate_path_coverage "/features/.*/domain/usecases/" "  Use Cases"
  calculate_path_coverage "/features/.*/domain/entities/" "  Entities"
  calculate_path_coverage "/features/.*/domain/repositories/" "  Repository Interfaces"
  echo ""

  echo -e "${YELLOW}Data Layer:${NC}"
  calculate_path_coverage "/features/.*/data/" "  Overall"
  calculate_path_coverage "/features/.*/data/repositories/" "  Repository Implementations"
  calculate_path_coverage "/features/.*/data/datasources/" "  Data Sources"
  calculate_path_coverage "/features/.*/data/models/" "  Models"
  echo ""

  echo -e "${YELLOW}Presentation Layer:${NC}"
  calculate_path_coverage "/features/.*/presentation/" "  Overall"
  calculate_path_coverage "/features/.*/presentation/providers/" "  Providers"
  calculate_path_coverage "/features/.*/presentation/screens/" "  Screens"
  calculate_path_coverage "/features/.*/presentation/widgets/" "  Widgets"
  echo ""

  echo -e "${YELLOW}Core Layer:${NC}"
  calculate_path_coverage "/core/" "  Overall"
  calculate_path_coverage "/core/network/" "  Network"
  calculate_path_coverage "/core/storage/" "  Storage"
  calculate_path_coverage "/core/config/" "  Config"
  calculate_path_coverage "/core/utils/" "  Utils"
  calculate_path_coverage "/core/errors/" "  Errors"
  calculate_path_coverage "/core/performance/" "  Performance"
  echo ""

  echo -e "${YELLOW}Shared Layer:${NC}"
  calculate_path_coverage "/shared/" "  Overall"
  echo ""

  # One line per file, counted within its own record.
  echo -e "${BLUE}=== Files with Low Coverage (< 60%) ===${NC}"
  echo ""
  awk '
    /^SF:/ { file = substr($0, 4); total = 0; covered = 0 }
    /^DA:/ { total++; split($0, p, ","); if (p[2] != "0") covered++ }
    /^end_of_record/ {
      if (total > 0 && covered / total < 0.6) {
        printf "%s: %.1f%%\n", file, (covered / total) * 100
      }
    }
  ' "$FILTERED" | head -20 | while IFS= read -r low; do
    echo -e "${RED}${low}${NC}"
  done

  echo ""
fi

# Check against minimum threshold (after analysis if requested)
if ! is_percent "$COVERAGE_PERCENT"; then
  echo -e "${RED}✗ Could not measure coverage (got '${COVERAGE_PERCENT}'), so the threshold check fails${NC}"
  EXIT_CODE=1
elif below "$COVERAGE_PERCENT" "$MIN_COVERAGE"; then
  echo -e "${RED}✗ Coverage ${COVERAGE_PERCENT}% is below minimum threshold of ${MIN_COVERAGE}%${NC}"
  EXIT_CODE=1
else
  echo -e "${GREEN}✓ Coverage ${COVERAGE_PERCENT}% meets minimum threshold of ${MIN_COVERAGE}%${NC}"
  EXIT_CODE=0
fi

echo ""
echo -e "${GREEN}Coverage report complete!${NC}"

exit $EXIT_CODE


