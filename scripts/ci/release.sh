#!/bin/bash

# Release automation script for Flutter Starter
# Usage: ./scripts/ci/release.sh [major|minor|patch]
#
# The changelog covers commits since the last tag reachable from HEAD. For the
# first release, when there is no such tag, set RELEASE_CHANGELOG_SINCE=<ref>;
# generate_changelog.sh refuses otherwise rather than listing every commit.

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

# The release branch and tag names are known before anything changes: the
# bump is computed on a copy of pubspec.yaml. If either already exists (a
# re-run after a declined push, say), stop here. Found at step 5 or 7, the
# failure used to leave pubspec.yaml and CHANGELOG.md rewritten.
PROBE_PUBSPEC=$(mktemp)
cp pubspec.yaml "$PROBE_PUBSPEC"
if ! PUBSPEC_PATH="$PROBE_PUBSPEC" ./scripts/ci/bump_version.sh "$BUMP_TYPE" >/dev/null; then
    rm -f "$PROBE_PUBSPEC"
    echo -e "${RED}Version bump failed. Aborting release.${NC}"
    exit 1
fi
NEXT_VERSION=$(grep "^version:" "$PROBE_PUBSPEC" | sed 's/version: //' | cut -d'+' -f1)
rm -f "$PROBE_PUBSPEC"
if git show-ref --verify --quiet "refs/heads/release/v$NEXT_VERSION"; then
    echo -e "${RED}Error: branch release/v$NEXT_VERSION already exists. Nothing was changed.${NC}"
    echo "Delete it (git branch -D release/v$NEXT_VERSION) or release from it."
    exit 1
fi
if git show-ref --verify --quiet "refs/tags/v$NEXT_VERSION"; then
    echo -e "${RED}Error: tag v$NEXT_VERSION already exists. Nothing was changed.${NC}"
    echo "Delete it (git tag -d v$NEXT_VERSION) or bump past it."
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

# Steps 3 and 4 change pubspec.yaml and CHANGELOG.md, and the two land together
# or not at all. The tree was clean when we started (checked above), so undoing
# means restoring both files to HEAD - and deleting CHANGELOG.md if step 4 was
# what created it. Without this, a failed step 4 used to leave a bumped pubspec.yaml with no changelog, no branch, no commit and no tag.
rollback_release_files() {
    git checkout -- pubspec.yaml
    if git ls-files --error-unmatch CHANGELOG.md >/dev/null 2>&1; then
        git checkout -- CHANGELOG.md
    else
        rm -f CHANGELOG.md
    fi
    echo -e "${YELLOW}Rolled back pubspec.yaml and CHANGELOG.md; the tree is as" \
        "it was before the release started.${NC}"
}

# Step 3: Bump version
echo -e "${YELLOW}Step 3: Bumping version...${NC}"
if ! ./scripts/ci/bump_version.sh "$BUMP_TYPE"; then
    echo -e "${RED}Version bump failed. Aborting release.${NC}"
    rollback_release_files
    exit 1
fi
NEW_VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //' | cut -d'+' -f1)
echo -e "${GREEN}✓ Version bumped to $NEW_VERSION${NC}"
echo ""

# Step 4: Generate changelog
echo -e "${YELLOW}Step 4: Generating changelog...${NC}"
if ! ./scripts/ci/generate_changelog.sh "$NEW_VERSION" ${RELEASE_CHANGELOG_SINCE:+--since "$RELEASE_CHANGELOG_SINCE"}; then
    echo -e "${RED}Changelog generation failed. Aborting release.${NC}"
    rollback_release_files
    exit 1
fi
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
# The deploy workflows ship with their push triggers commented out, so a
# pushed tag deploys only once setup_ci.dart --deploy-trigger=tags enabled
# one.
if grep -qE '^[[:space:]]+tags:' .github/workflows/deploy-*.yml 2>/dev/null; then
    echo "  1. The pushed tag starts the deploy workflows"
else
    echo "  1. No deploy workflow runs on a tag yet: dispatch them from the"
    echo "     Actions tab, or enable the trigger with"
    echo "     dart run scripts/dev/setup_ci.dart --deploy-trigger=tags"
fi
echo "  2. Monitor GitHub Actions for build status"
echo "  3. After successful deployment, merge release branch:"
echo "     git checkout main"
echo "     git merge $RELEASE_BRANCH"
echo "     git push origin main"
echo ""
echo -e "${BLUE}Release: v$NEW_VERSION${NC}"


