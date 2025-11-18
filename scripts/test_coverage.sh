#!/bin/bash

# Test coverage script
# Usage: ./scripts/test_coverage.sh [options]
# Options:
#   --html          Generate HTML coverage report
#   --open          Open HTML report after generation
#   --min=<percent> Set minimum coverage threshold (default: 80)
#   --exclude=<path> Exclude path from coverage (can be used multiple times)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
GENERATE_HTML=false
OPEN_HTML=false
MIN_COVERAGE=80
EXCLUDE_PATHS=()

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
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Usage: ./scripts/test_coverage.sh [--html] [--open] [--min=<percent>] [--exclude=<path>]"
      exit 1
      ;;
  esac
done

echo -e "${BLUE}Running tests with coverage...${NC}"
echo ""

# Run tests with coverage
flutter test --coverage

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

# Use lcov to get coverage summary
if command -v lcov &> /dev/null; then
  COVERAGE_SUMMARY=$(lcov --summary coverage/lcov.info 2>&1 | grep "lines.*:" | head -1)
  COVERAGE_PERCENT=$(echo "$COVERAGE_SUMMARY" | grep -oP '\d+\.\d+%' | head -1 | sed 's/%//')
  
  if [ -z "$COVERAGE_PERCENT" ]; then
    # Fallback: parse from lcov.info directly
    TOTAL_LINES=$(grep -c "^DA:" coverage/lcov.info || echo "0")
    COVERED_LINES=$(grep "^DA:" coverage/lcov.info | grep -v ",0$" | wc -l || echo "0")
    if [ "$TOTAL_LINES" -gt 0 ]; then
      COVERAGE_PERCENT=$(awk "BEGIN {printf \"%.2f\", ($COVERED_LINES / $TOTAL_LINES) * 100}")
    else
      COVERAGE_PERCENT=0
    fi
  fi
  
  echo -e "${BLUE}Coverage: ${COVERAGE_PERCENT}%${NC}"
  echo ""
  
  # Check against minimum threshold
  if (( $(echo "$COVERAGE_PERCENT < $MIN_COVERAGE" | bc -l) )); then
    echo -e "${RED}✗ Coverage ${COVERAGE_PERCENT}% is below minimum threshold of ${MIN_COVERAGE}%${NC}"
    exit 1
  else
    echo -e "${GREEN}✓ Coverage ${COVERAGE_PERCENT}% meets minimum threshold of ${MIN_COVERAGE}%${NC}"
  fi
else
  echo -e "${YELLOW}Warning: lcov not found. Cannot calculate coverage percentage${NC}"
  echo "Coverage data available at: coverage/lcov.info"
fi

echo ""
echo -e "${GREEN}Coverage report complete!${NC}"

