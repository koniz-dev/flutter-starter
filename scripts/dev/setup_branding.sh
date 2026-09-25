#!/bin/bash

# Script to generate app icons and splash screens
# Usage: ./scripts/dev/setup_branding.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

LOGO_PATH="assets/images/logo.png"

echo -e "${BLUE}Starting Branding Setup...${NC}"

# There is no fallback. flutter_launcher_icons aborts when image_path is missing
# ("Image not found") and flutter_native_splash does the same, so continuing here
# would only move the failure two lines down with a worse message. Both
# flutter_launcher_icons.yaml and flutter_native_splash.yaml point at
# $LOGO_PATH, and a fresh clone ships assets/images/ empty on purpose.
if [ ! -f "$LOGO_PATH" ]; then
    echo -e "${RED}Error: $LOGO_PATH not found.${NC}" >&2
    echo "" >&2
    echo "Place a high-resolution logo (1024x1024 PNG recommended) at $LOGO_PATH" >&2
    echo "and re-run this script. Both flutter_launcher_icons.yaml and" >&2
    echo "flutter_native_splash.yaml read that exact path; change them together" >&2
    echo "with this script if you want a different location." >&2
    exit 1
fi

echo -e "${GREEN}Logo found at $LOGO_PATH${NC}"

echo -e "\n${YELLOW}Generating App Icons...${NC}"
dart run flutter_launcher_icons

echo -e "\n${YELLOW}Generating Native Splash Screens...${NC}"
dart run flutter_native_splash:create

echo -e "\n${GREEN}Branding setup complete!${NC}"
echo "Your app now has custom icons and splash screens tailored for iOS, Android, and Web."
