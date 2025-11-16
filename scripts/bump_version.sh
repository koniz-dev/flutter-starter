#!/bin/bash

# Version bumping script for Flutter Starter
# Usage: ./scripts/bump_version.sh [major|minor|patch|build] [build_number]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get current version from pubspec.yaml
CURRENT_VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //')
VERSION_PART=$(echo $CURRENT_VERSION | cut -d'+' -f1)
BUILD_NUMBER=$(echo $CURRENT_VERSION | cut -d'+' -f2)

# Parse arguments
BUMP_TYPE=${1:-patch}
CUSTOM_BUILD=${2:-}

if [ -z "$BUMP_TYPE" ]; then
    echo -e "${RED}Error: Bump type required${NC}"
    echo "Usage: $0 [major|minor|patch|build] [build_number]"
    exit 1
fi

# Parse version parts
IFS='.' read -ra VERSION_PARTS <<< "$VERSION_PART"
MAJOR=${VERSION_PARTS[0]}
MINOR=${VERSION_PARTS[1]}
PATCH=${VERSION_PARTS[2]}

# Bump version based on type
case $BUMP_TYPE in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        BUILD_NUMBER=$((BUILD_NUMBER + 1))
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        BUILD_NUMBER=$((BUILD_NUMBER + 1))
        ;;
    patch)
        PATCH=$((PATCH + 1))
        BUILD_NUMBER=$((BUILD_NUMBER + 1))
        ;;
    build)
        BUILD_NUMBER=$((BUILD_NUMBER + 1))
        ;;
    *)
        echo -e "${RED}Error: Invalid bump type '$BUMP_TYPE'${NC}"
        echo "Valid types: major, minor, patch, build"
        exit 1
        ;;
esac

# Use custom build number if provided
if [ -n "$CUSTOM_BUILD" ]; then
    BUILD_NUMBER=$CUSTOM_BUILD
fi

# Create new version string
NEW_VERSION="$MAJOR.$MINOR.$PATCH+$BUILD_NUMBER"

# Update pubspec.yaml
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml
else
    # Linux
    sed -i "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml
fi

# Output result
echo -e "${GREEN}Version bumped successfully!${NC}"
echo -e "  ${YELLOW}Old version:${NC} $CURRENT_VERSION"
echo -e "  ${YELLOW}New version:${NC} $NEW_VERSION"
echo ""
echo "Don't forget to:"
echo "  1. Commit the version change"
echo "  2. Update CHANGELOG.md"
echo "  3. Create a release tag"

