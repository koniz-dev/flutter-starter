#!/bin/bash

# Release automation script for Flutter Starter
# Usage: ./scripts/release.sh [major|minor|patch]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if we're on main branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ] && [ "$CURRENT_BRANCH" != "master" ]; then
    echo -e "${RED}Error: Must be on main/master branch to release${NC}"
    exit 1
fi

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    echo -e "${RED}Error: Uncommitted changes detected${NC}"
    echo "Please commit or stash your changes before releasing"
    exit 1
fi

# Get bump type
BUMP_TYPE=${1:-patch}

if [ "$BUMP_TYPE" != "major" ] && [ "$BUMP_TYPE" != "minor" ] && [ "$BUMP_TYPE" != "patch" ]; then
    echo -e "${RED}Error: Invalid bump type '$BUMP_TYPE'${NC}"
    echo "Valid types: major, minor, patch"
    exit 1
fi

echo -e "${BLUE}Starting release process...${NC}"
echo ""

# Step 1: Run tests
echo -e "${YELLOW}Step 1: Running tests...${NC}"
flutter test
if [ $? -ne 0 ]; then
    echo -e "${RED}Tests failed. Aborting release.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Tests passed${NC}"
echo ""

# Step 2: Run analysis
echo -e "${YELLOW}Step 2: Running analysis...${NC}"
flutter analyze
if [ $? -ne 0 ]; then
    echo -e "${RED}Analysis failed. Aborting release.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Analysis passed${NC}"
echo ""

# Step 3: Bump version
echo -e "${YELLOW}Step 3: Bumping version...${NC}"
./scripts/bump_version.sh $BUMP_TYPE
NEW_VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //' | cut -d'+' -f1)
echo -e "${GREEN}✓ Version bumped to $NEW_VERSION${NC}"
echo ""

# Step 4: Generate changelog
echo -e "${YELLOW}Step 4: Generating changelog...${NC}"
./scripts/generate_changelog.sh $NEW_VERSION
echo -e "${GREEN}✓ Changelog generated${NC}"
echo ""

# Step 5: Create release branch
RELEASE_BRANCH="release/v$NEW_VERSION"
echo -e "${YELLOW}Step 5: Creating release branch...${NC}"
git checkout -b $RELEASE_BRANCH
echo -e "${GREEN}✓ Release branch created: $RELEASE_BRANCH${NC}"
echo ""

# Step 6: Commit changes
echo -e "${YELLOW}Step 6: Committing changes...${NC}"
git add pubspec.yaml CHANGELOG.md
git commit -m "chore: prepare release v$NEW_VERSION"
echo -e "${GREEN}✓ Changes committed${NC}"
echo ""

# Step 7: Create tag
echo -e "${YELLOW}Step 7: Creating release tag...${NC}"
git tag -a "v$NEW_VERSION" -m "Release v$NEW_VERSION"
echo -e "${GREEN}✓ Tag created: v$NEW_VERSION${NC}"
echo ""

# Step 8: Push
echo -e "${YELLOW}Step 8: Pushing to remote...${NC}"
read -p "Push release branch and tag? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    git push origin $RELEASE_BRANCH
    git push origin "v$NEW_VERSION"
    echo -e "${GREEN}✓ Pushed to remote${NC}"
else
    echo -e "${YELLOW}⚠ Skipped push. Push manually with:${NC}"
    echo "  git push origin $RELEASE_BRANCH"
    echo "  git push origin v$NEW_VERSION"
fi
echo ""

# Summary
echo -e "${GREEN}Release preparation complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. CI/CD will automatically build and deploy"
echo "  2. Monitor GitHub Actions for build status"
echo "  3. After successful deployment, merge release branch:"
echo "     git checkout main"
echo "     git merge $RELEASE_BRANCH"
echo "     git push origin main"
echo ""
echo -e "${BLUE}Release: v$NEW_VERSION${NC}"

