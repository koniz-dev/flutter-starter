#!/bin/bash

# Script to run E2E Patrol tests
# Requires patrol_cli globally: `dart pub global activate patrol_cli 3.11.0`
# The CLI version must match the `patrol` dependency in pubspec.yaml - see
# https://patrol.leancode.co/documentation/compatibility-table
# Usage: ./scripts/test/run_e2e_tests.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Starting E2E Tests with Patrol...${NC}"

if ! command -v patrol &> /dev/null
then
    echo -e "${RED}patrol could not be found.${NC}"
    echo "Please install it by running: dart pub global activate patrol_cli 3.11.0"
    echo "(the version must match 'patrol' in pubspec.yaml; see the Patrol compatibility table)"
    exit 1
fi

patrol test -t integration_test/auth_flow_test.dart

echo -e "${GREEN}✅ E2E tests complete!${NC}"
