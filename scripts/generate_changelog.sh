#!/bin/bash

# Changelog generation script for Flutter Starter
# Usage: ./scripts/generate_changelog.sh [version]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get version from argument or pubspec.yaml
if [ -n "$1" ]; then
    VERSION=$1
else
    VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //' | cut -d'+' -f1)
fi

# Get current date
DATE=$(date +%Y-%m-%d)

# Get last tag
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [ -z "$LAST_TAG" ]; then
    echo -e "${YELLOW}Warning: No previous tag found. Using all commits.${NC}"
    COMMITS=$(git log --pretty=format:"%s" --no-merges)
else
    echo -e "${GREEN}Generating changelog from $LAST_TAG to HEAD${NC}"
    COMMITS=$(git log --pretty=format:"%s" --no-merges ${LAST_TAG}..HEAD)
fi

# Initialize changelog sections
ADDED=""
CHANGED=""
FIXED=""
SECURITY=""
PERF=""
REFACTOR=""
DOCS=""
STYLE=""
TEST=""
CHORE=""
CI=""
BUILD=""
REVERT=""

# Parse commits
while IFS= read -r commit; do
    if [ -z "$commit" ]; then
        continue
    fi
    
    # Extract type and message
    TYPE=$(echo "$commit" | cut -d':' -f1 | cut -d'(' -f1 | tr '[:upper:]' '[:lower:]')
    MESSAGE=$(echo "$commit" | cut -d':' -f2- | sed 's/^ *//')
    
    case $TYPE in
        feat*)
            ADDED="${ADDED}- ${MESSAGE}\n"
            ;;
        fix*)
            FIXED="${FIXED}- ${MESSAGE}\n"
            ;;
        security*)
            SECURITY="${SECURITY}- ${MESSAGE}\n"
            ;;
        perf*)
            PERF="${PERF}- ${MESSAGE}\n"
            ;;
        refactor*)
            REFACTOR="${REFACTOR}- ${MESSAGE}\n"
            ;;
        docs*)
            DOCS="${DOCS}- ${MESSAGE}\n"
            ;;
        style*)
            STYLE="${STYLE}- ${MESSAGE}\n"
            ;;
        test*)
            TEST="${TEST}- ${MESSAGE}\n"
            ;;
        chore*)
            CHORE="${CHORE}- ${MESSAGE}\n"
            ;;
        ci*)
            CI="${CI}- ${MESSAGE}\n"
            ;;
        build*)
            BUILD="${BUILD}- ${MESSAGE}\n"
            ;;
        revert*)
            REVERT="${REVERT}- ${MESSAGE}\n"
            ;;
        *)
            # Default to changed for unknown types
            CHANGED="${CHANGED}- ${MESSAGE}\n"
            ;;
    esac
done <<< "$COMMITS"

# Generate changelog entry
CHANGELOG_ENTRY="## [$VERSION] - $DATE\n\n"

if [ -n "$ADDED" ]; then
    CHANGELOG_ENTRY="${CHANGELOG_ENTRY}### Added\n${ADDED}\n"
fi

if [ -n "$CHANGED" ]; then
    CHANGELOG_ENTRY="${CHANGELOG_ENTRY}### Changed\n${CHANGED}\n"
fi

if [ -n "$FIXED" ]; then
    CHANGELOG_ENTRY="${CHANGELOG_ENTRY}### Fixed\n${FIXED}\n"
fi

if [ -n "$SECURITY" ]; then
    CHANGELOG_ENTRY="${CHANGELOG_ENTRY}### Security\n${SECURITY}\n"
fi

if [ -n "$PERF" ]; then
    CHANGELOG_ENTRY="${CHANGELOG_ENTRY}### Performance\n${PERF}\n"
fi

if [ -n "$REFACTOR" ]; then
    CHANGELOG_ENTRY="${CHANGELOG_ENTRY}### Refactored\n${REFACTOR}\n"
fi

if [ -n "$DOCS" ]; then
    CHANGELOG_ENTRY="${CHANGELOG_ENTRY}### Documentation\n${DOCS}\n"
fi

if [ -n "$STYLE" ]; then
    CHANGELOG_ENTRY="${CHANGELOG_ENTRY}### Style\n${STYLE}\n"
fi

if [ -n "$TEST" ]; then
    CHANGELOG_ENTRY="${CHANGELOG_ENTRY}### Tests\n${TEST}\n"
fi

if [ -n "$CHORE" ]; then
    CHANGELOG_ENTRY="${CHANGELOG_ENTRY}### Chore\n${CHORE}\n"
fi

if [ -n "$CI" ]; then
    CHANGELOG_ENTRY="${CHANGELOG_ENTRY}### CI/CD\n${CI}\n"
fi

if [ -n "$BUILD" ]; then
    CHANGELOG_ENTRY="${CHANGELOG_ENTRY}### Build\n${BUILD}\n"
fi

if [ -n "$REVERT" ]; then
    CHANGELOG_ENTRY="${CHANGELOG_ENTRY}### Reverted\n${REVERT}\n"
fi

# Check if CHANGELOG.md exists
if [ ! -f "CHANGELOG.md" ]; then
    echo -e "${YELLOW}Creating CHANGELOG.md${NC}"
    cat > CHANGELOG.md << EOF
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

EOF
fi

# Prepend to CHANGELOG.md
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "1a\\
${CHANGELOG_ENTRY}
" CHANGELOG.md
else
    # Linux
    sed -i "1a\\${CHANGELOG_ENTRY}" CHANGELOG.md
fi

echo -e "${GREEN}Changelog generated successfully!${NC}"
echo -e "  ${YELLOW}Version:${NC} $VERSION"
echo -e "  ${YELLOW}Date:${NC} $DATE"
echo ""
echo "Review CHANGELOG.md and commit if satisfied."

