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

echo -e "${BLUE}Starting Branding Setup...${NC}"

# Check if logo exists
if [ ! -f "assets/images/logo.png" ]; then
    echo -e "${YELLOW}Warning: assets/images/logo.png not found!${NC}"
    echo "Please place a high-resolution logo (1024x1024 recommended) at assets/images/logo.png"
    echo "Falling back to default Flutter logo if packages are run anyway."
else
    echo -e "${GREEN}✓ Logo found at assets/images/logo.png${NC}"
fi

echo -e "\n${YELLOW}Generating App Icons...${NC}"
flutter pub run flutter_launcher_icons

echo -e "\n${YELLOW}Generating Native Splash Screens...${NC}"
flutter pub run flutter_native_splash:create

echo -e "\n${GREEN}✅ Branding setup complete!${NC}"
echo "Your app now has custom icons and splash screens tailored for iOS, Android, and Web."
