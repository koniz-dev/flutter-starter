#!/bin/bash

# Script to run E2E Patrol tests
# Requires patrol_cli to be installed globally: `dart pub global activate patrol_cli`
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
    echo "Please install it by running: dart pub global activate patrol_cli"
    exit 1
fi

patrol test -t integration_test/auth_flow_test.dart

echo -e "${GREEN}✅ E2E tests complete!${NC}"
