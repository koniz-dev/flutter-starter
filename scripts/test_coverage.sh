#!/bin/bash

# Test coverage script
# Usage: ./scripts/test_coverage.sh [options]
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
      echo "Usage: ./scripts/test_coverage.sh [--html] [--open] [--min=<percent>] [--exclude=<path>] [--analyze] [--no-test]"
      exit 1
      ;;
  esac
done

# Run tests with coverage (unless skipped)
if [ "$SKIP_TEST" = false ]; then
  echo -e "${BLUE}Running tests with coverage...${NC}"
  echo ""
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
  
  # Generate HTML report
  genhtml coverage/lcov.info -o coverage/html --no-function-coverage
  
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

# Function to calculate coverage from lcov.info directly
calculate_coverage() {
  local TOTAL_LINES=0
  local COVERED_LINES=0
  
  while IFS= read -r line; do
    if [[ $line =~ ^DA: ]]; then
      TOTAL_LINES=$((TOTAL_LINES + 1))
      # Extract execution count (number after comma)
      exec_count=$(echo "$line" | cut -d',' -f2)
      if [ "$exec_count" -gt 0 ] 2>/dev/null; then
        COVERED_LINES=$((COVERED_LINES + 1))
      fi
    fi
  done < coverage/lcov.info
  
  if [ "$TOTAL_LINES" -gt 0 ]; then
    COVERAGE_PERCENT=$(awk "BEGIN {printf \"%.2f\", ($COVERED_LINES / $TOTAL_LINES) * 100}")
    echo "$COVERAGE_PERCENT|$TOTAL_LINES|$COVERED_LINES"
  else
    echo "0|0|0"
  fi
}

# Try to use lcov command if available (more accurate), otherwise parse directly
if command -v lcov &> /dev/null; then
  COVERAGE_SUMMARY=$(lcov --summary coverage/lcov.info 2>&1 | grep "lines.*:" | head -1)
  COVERAGE_PERCENT=$(echo "$COVERAGE_SUMMARY" | grep -oP '\d+\.\d+%' | head -1 | sed 's/%//')
  
  # If lcov summary parsing failed, use direct calculation
  if [ -z "$COVERAGE_PERCENT" ]; then
    RESULT=$(calculate_coverage)
    COVERAGE_PERCENT=$(echo "$RESULT" | cut -d'|' -f1)
    TOTAL_LINES=$(echo "$RESULT" | cut -d'|' -f2)
    COVERED_LINES=$(echo "$RESULT" | cut -d'|' -f3)
  else
    # Extract total and covered from lcov summary if possible
    TOTAL_LINES=$(echo "$COVERAGE_SUMMARY" | grep -oP '\d+(?=\s+lines)' | head -1 || echo "")
    COVERED_LINES=$(echo "$COVERAGE_SUMMARY" | grep -oP '\d+(?=\s+of)' | head -1 || echo "")
  fi
else
  # Parse directly from lcov.info
  RESULT=$(calculate_coverage)
  COVERAGE_PERCENT=$(echo "$RESULT" | cut -d'|' -f1)
  TOTAL_LINES=$(echo "$RESULT" | cut -d'|' -f2)
  COVERED_LINES=$(echo "$RESULT" | cut -d'|' -f3)
fi

# Display coverage statistics
if [ -n "$TOTAL_LINES" ] && [ "$TOTAL_LINES" != "0" ]; then
  echo -e "${BLUE}Coverage Statistics:${NC}"
  echo -e "  Total lines: ${TOTAL_LINES}"
  echo -e "  Covered lines: ${COVERED_LINES}"
  echo -e "  Coverage: ${COVERAGE_PERCENT}%"
  echo ""
else
  echo -e "${BLUE}Coverage: ${COVERAGE_PERCENT}%${NC}"
  echo ""
fi

# Check against minimum threshold
if (( $(echo "$COVERAGE_PERCENT < $MIN_COVERAGE" | bc -l) )); then
  echo -e "${RED}✗ Coverage ${COVERAGE_PERCENT}% is below minimum threshold of ${MIN_COVERAGE}%${NC}"
  exit 1
else
  echo -e "${GREEN}✓ Coverage ${COVERAGE_PERCENT}% meets minimum threshold of ${MIN_COVERAGE}%${NC}"
fi

# Analyze coverage by layer if requested
if [ "$ANALYZE_COVERAGE" = true ]; then
  echo ""
  echo -e "${BLUE}=== Coverage Analysis by Layer ===${NC}"
  echo ""
  
  # Function to calculate coverage for a path
  calculate_path_coverage() {
    local path=$1
    local name=$2
    
    # Extract coverage data for the path
    local total_lines=$(grep "^SF:.*$path" coverage/lcov.info -A 1000 | grep "^DA:" | wc -l || echo "0")
    local covered_lines=$(grep "^SF:.*$path" coverage/lcov.info -A 1000 | grep "^DA:" | grep -v ",0$" | wc -l || echo "0")
    
    if [ "$total_lines" -gt 0 ]; then
      local percent=$(awk "BEGIN {printf \"%.1f\", ($covered_lines / $total_lines) * 100}")
      echo -e "${CYAN}$name:${NC} $covered_lines/$total_lines lines ($percent%)"
      
      # Color code based on coverage
      if (( $(echo "$percent >= 80" | bc -l) )); then
        echo -e "  ${GREEN}✓ Good coverage${NC}"
      elif (( $(echo "$percent >= 60" | bc -l) )); then
        echo -e "  ${YELLOW}⚠ Needs improvement${NC}"
      else
        echo -e "  ${RED}✗ Low coverage${NC}"
      fi
    else
      echo -e "${CYAN}$name:${NC} No coverage data"
    fi
  }
  
  # Domain Layer
  echo -e "${YELLOW}Domain Layer:${NC}"
  calculate_path_coverage "lib/features/.*/domain" "  Overall"
  calculate_path_coverage "lib/features/.*/domain/usecases" "  Use Cases"
  calculate_path_coverage "lib/features/.*/domain/entities" "  Entities"
  calculate_path_coverage "lib/features/.*/domain/repositories" "  Repository Interfaces"
  echo ""
  
  # Data Layer
  echo -e "${YELLOW}Data Layer:${NC}"
  calculate_path_coverage "lib/features/.*/data" "  Overall"
  calculate_path_coverage "lib/features/.*/data/repositories" "  Repository Implementations"
  calculate_path_coverage "lib/features/.*/data/datasources" "  Data Sources"
  calculate_path_coverage "lib/features/.*/data/models" "  Models"
  echo ""
  
  # Presentation Layer
  echo -e "${YELLOW}Presentation Layer:${NC}"
  calculate_path_coverage "lib/features/.*/presentation" "  Overall"
  calculate_path_coverage "lib/features/.*/presentation/providers" "  Providers"
  calculate_path_coverage "lib/features/.*/presentation/screens" "  Screens"
  calculate_path_coverage "lib/features/.*/presentation/widgets" "  Widgets"
  echo ""
  
  # Core Layer
  echo -e "${YELLOW}Core Layer:${NC}"
  calculate_path_coverage "lib/core" "  Overall"
  calculate_path_coverage "lib/core/network" "  Network"
  calculate_path_coverage "lib/core/storage" "  Storage"
  calculate_path_coverage "lib/core/config" "  Config"
  calculate_path_coverage "lib/core/utils" "  Utils"
  calculate_path_coverage "lib/core/errors" "  Errors"
  calculate_path_coverage "lib/core/performance" "  Performance"
  echo ""
  
  # Shared Layer
  echo -e "${YELLOW}Shared Layer:${NC}"
  calculate_path_coverage "lib/shared" "  Overall"
  echo ""
  
  # Find files with low coverage
  echo -e "${BLUE}=== Files with Low Coverage (< 60%) ===${NC}"
  echo ""
  
  # This is a simplified check - in practice, you'd want more sophisticated parsing
  grep "^SF:" coverage/lcov.info | while read -r file_line; do
    file_path=$(echo "$file_line" | sed 's/^SF://')
    
    # Get coverage for this file
    file_start=$(grep -n "^SF:$file_path" coverage/lcov.info | cut -d: -f1)
    if [ -n "$file_start" ]; then
      # Extract DA lines for this file (until next SF or end)
      total=$(sed -n "${file_start},\$p" coverage/lcov.info | grep "^DA:" | head -100 | wc -l)
      covered=$(sed -n "${file_start},\$p" coverage/lcov.info | grep "^DA:" | head -100 | grep -v ",0$" | wc -l)
      
      if [ "$total" -gt 0 ]; then
        percent=$(awk "BEGIN {printf \"%.1f\", ($covered / $total) * 100}")
        if (( $(echo "$percent < 60" | bc -l) )); then
          echo -e "${RED}$file_path: $percent%${NC}"
        fi
      fi
    fi
  done | head -20
  
  echo ""
fi

echo ""
echo -e "${GREEN}Coverage report complete!${NC}"

