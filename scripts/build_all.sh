#!/bin/bash

# Build script for all platforms
# Usage: ./scripts/build_all.sh [environment]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get environment
ENVIRONMENT=${1:-production}

if [ "$ENVIRONMENT" != "development" ] && [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "production" ]; then
    echo -e "${RED}Error: Invalid environment '$ENVIRONMENT'${NC}"
    echo "Valid environments: development, staging, production"
    exit 1
fi

# Set base URL based on environment
case $ENVIRONMENT in
    development)
        BASE_URL="http://localhost:3000"
        ;;
    staging)
        BASE_URL="${BASE_URL_STAGING:-https://api-staging.example.com}"
        ;;
    production)
        BASE_URL="${BASE_URL_PRODUCTION:-https://api.example.com}"
        ;;
esac

echo -e "${BLUE}Building for environment: $ENVIRONMENT${NC}"
echo "Base URL: $BASE_URL"
echo ""

# Clean previous builds
echo -e "${YELLOW}Cleaning previous builds...${NC}"
flutter clean
flutter pub get
echo -e "${GREEN}✓ Cleaned${NC}"
echo ""

# Build Android
echo -e "${YELLOW}Building Android...${NC}"
if [ "$ENVIRONMENT" == "production" ]; then
    flutter build appbundle \
        --flavor production \
        --release \
        --dart-define=ENVIRONMENT=$ENVIRONMENT \
        --dart-define=BASE_URL=$BASE_URL
    echo -e "${GREEN}✓ Android App Bundle built${NC}"
else
    flutter build apk \
        --flavor $ENVIRONMENT \
        --dart-define=ENVIRONMENT=$ENVIRONMENT \
        --dart-define=BASE_URL=$BASE_URL
    echo -e "${GREEN}✓ Android APK built${NC}"
fi
echo ""

# Build iOS (only on macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "${YELLOW}Building iOS...${NC}"
    if [ "$ENVIRONMENT" == "production" ]; then
        flutter build ipa \
            --release \
            --dart-define=ENVIRONMENT=$ENVIRONMENT \
            --dart-define=BASE_URL=$BASE_URL
        echo -e "${GREEN}✓ iOS IPA built${NC}"
    else
        flutter build ios \
            --flavor $ENVIRONMENT \
            --no-codesign \
            --dart-define=ENVIRONMENT=$ENVIRONMENT \
            --dart-define=BASE_URL=$BASE_URL
        echo -e "${GREEN}✓ iOS build completed${NC}"
    fi
    echo ""
else
    echo -e "${YELLOW}⚠ Skipping iOS build (not on macOS)${NC}"
    echo ""
fi

# Build Web
echo -e "${YELLOW}Building Web...${NC}"
if [ "$ENVIRONMENT" == "production" ]; then
    flutter build web \
        --release \
        --web-renderer canvaskit \
        --dart-define=ENVIRONMENT=$ENVIRONMENT \
        --dart-define=BASE_URL=$BASE_URL
else
    flutter build web \
        --dart-define=ENVIRONMENT=$ENVIRONMENT \
        --dart-define=BASE_URL=$BASE_URL
fi
echo -e "${GREEN}✓ Web build completed${NC}"
echo ""

# Summary
echo -e "${GREEN}All builds completed!${NC}"
echo ""
echo "Build artifacts:"
echo "  Android: build/app/outputs/"
echo "  iOS: build/ios/ipa/"
echo "  Web: build/web/"

