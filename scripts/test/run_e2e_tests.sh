#!/bin/bash

# Script to run E2E Patrol tests
# Requires patrol_cli globally: `dart pub global activate patrol_cli 4.9.0`
# The CLI version must match the `patrol` dependency in pubspec.yaml - see
# https://patrol.leancode.co/documentation/compatibility-table
# Usage: ./scripts/test/run_e2e_tests.sh

set -eo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Starting E2E Tests with Patrol...${NC}"

if ! command -v patrol &> /dev/null
then
    echo -e "${RED}patrol could not be found.${NC}"
    echo "Please install it by running: dart pub global activate patrol_cli 4.9.0"
    echo "(the version must match 'patrol' in pubspec.yaml; see the Patrol compatibility table)"
    exit 1
fi

# The same target e2e-android.yml runs, so the local and CI E2E paths test
# one file.
PATROL_LOG="$(mktemp)"
trap 'rm -f "$PATROL_LOG"' EXIT
patrol test -t integration_test/app_e2e_test.dart 2>&1 | tee "$PATROL_LOG"

# `patrol test` exits 0 when it collected no test, or skipped them all: the
# same check e2e-android.yml applies.
"$(dirname "${BASH_SOURCE[0]}")/check_patrol_summary.sh" "$PATROL_LOG"

echo -e "${GREEN}✅ E2E tests complete!${NC}"
