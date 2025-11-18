#!/bin/bash

# Coverage analysis script
# Analyzes coverage by layer and identifies gaps
# Usage: ./scripts/analyze_coverage.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if coverage file exists
if [ ! -f "coverage/lcov.info" ]; then
  echo -e "${RED}Error: coverage/lcov.info not found${NC}"
  echo "Run 'flutter test --coverage' first"
  exit 1
fi

echo -e "${BLUE}Analyzing test coverage...${NC}"
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

# Analyze by layer
echo -e "${BLUE}=== Coverage by Layer ===${NC}"
echo ""

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
echo -e "${GREEN}Analysis complete!${NC}"
echo ""
echo "For detailed HTML report, run: ./scripts/test_coverage.sh --html"

