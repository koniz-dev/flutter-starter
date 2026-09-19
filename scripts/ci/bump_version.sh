#!/usr/bin/env bash

# Version bumping script for Flutter Starter
# Usage: ./scripts/ci/bump_version.sh [major|minor|patch|build] [build_number]
#
# The build number is OPTIONAL in a pubspec (`version: 1.0.0` is valid), so this
# script must cope with both shapes:
#
#   version: 1.0.0     -> patch -> 1.0.1      (no build segment invented)
#   version: 1.0.0+1   -> patch -> 1.0.1+2
#
# Everything is validated and computed BEFORE pubspec.yaml is touched, and the
# rewrite goes through a temp file that is moved into place only once it is
# complete. `release.sh` calls this after `flutter test` and `flutter analyze`
# have already run, so a mid-edit abort there used to leave a half-written
# pubspec behind (issue #57).
#
# Pre-release versions (`1.0.0-beta+1`) are rejected with an explanation rather
# than guessed at: what "bump the patch of a pre-release" should mean is a
# project decision, and silently picking one is worse than asking.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PUBSPEC="${PUBSPEC_PATH:-$ROOT/pubspec.yaml}"

die() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

# --- Parse arguments -------------------------------------------------------
BUMP_TYPE="${1:-patch}"
CUSTOM_BUILD="${2:-}"

case "$BUMP_TYPE" in
    major|minor|patch|build) ;;
    *)
        echo -e "${RED}Error: Invalid bump type '$BUMP_TYPE'${NC}" >&2
        echo "Usage: $0 [major|minor|patch|build] [build_number]" >&2
        echo "Valid types: major, minor, patch, build" >&2
        exit 1
        ;;
esac

if [ -n "$CUSTOM_BUILD" ] && ! [[ "$CUSTOM_BUILD" =~ ^[0-9]+$ ]]; then
    die "Build number must be a non-negative integer, got '$CUSTOM_BUILD'"
fi

# --- Read and validate the current version ---------------------------------
[ -f "$PUBSPEC" ] || die "pubspec.yaml not found at $PUBSPEC"

VERSION_LINE="$(grep -m1 '^version:' "$PUBSPEC" || true)"
[ -n "$VERSION_LINE" ] || die "no 'version:' line found in $PUBSPEC"

# Strip the key, a trailing comment, surrounding whitespace and any CR.
CURRENT_VERSION="$(printf '%s' "$VERSION_LINE" \
    | sed -e 's/^version:[[:space:]]*//' \
          -e 's/[[:space:]]*#.*$//' \
          -e 's/[[:space:]]*$//' \
          -e 's/\r$//')"

if ! [[ "$CURRENT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(\+[0-9]+)?$ ]]; then
    die "unsupported version '$CURRENT_VERSION' in $PUBSPEC (expected MAJOR.MINOR.PATCH[+BUILD]); pubspec.yaml left untouched"
fi

VERSION_PART="${CURRENT_VERSION%%+*}"
if [[ "$CURRENT_VERSION" == *"+"* ]]; then
    HAS_BUILD=true
    BUILD_NUMBER="${CURRENT_VERSION#*+}"
else
    # `cut -d'+' -f2` returns the WHOLE string when there is no '+', which is
    # what used to feed "1.0.0" into $(( ... )) and abort mid-run.
    HAS_BUILD=false
    BUILD_NUMBER=0
fi

IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION_PART"

# --- Compute the new version ----------------------------------------------
case "$BUMP_TYPE" in
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
        # An explicit `build` bump is a request for a build segment, so add one
        # even when the pubspec had none.
        HAS_BUILD=true
        ;;
esac

if [ -n "$CUSTOM_BUILD" ]; then
    BUILD_NUMBER="$CUSTOM_BUILD"
    HAS_BUILD=true
fi

if [ "$HAS_BUILD" = true ]; then
    NEW_VERSION="$MAJOR.$MINOR.$PATCH+$BUILD_NUMBER"
else
    # Preserve the pubspec's existing shape: no build number in, none out.
    NEW_VERSION="$MAJOR.$MINOR.$PATCH"
fi

# --- Rewrite pubspec.yaml atomically ---------------------------------------
# The temp file is a sibling of pubspec.yaml so the final `mv` is a same-
# filesystem rename: either the old file or the fully written new one is on
# disk, never a half-edited one. `cp -p` first so the rename keeps the original
# permissions.
TMP_FILE="$(mktemp "$(dirname "$PUBSPEC")/.pubspec.XXXXXX")"
cleanup() { rm -f "$TMP_FILE"; }
trap cleanup EXIT
cp -p "$PUBSPEC" "$TMP_FILE"

# Only the first top-level `version:` line is rewritten; awk keeps every other
# byte, including the trailing comment placement, exactly as it was.
awk -v new="version: $NEW_VERSION" '
    !done && /^version:/ { print new; done = 1; next }
    { print }
' "$PUBSPEC" > "$TMP_FILE"

grep -qx "version: $NEW_VERSION" "$TMP_FILE" \
    || die "rewrite produced no 'version: $NEW_VERSION' line; $PUBSPEC left untouched"

mv "$TMP_FILE" "$PUBSPEC"
trap - EXIT

# --- Output result ---------------------------------------------------------
echo -e "${GREEN}Version bumped successfully!${NC}"
echo -e "  ${YELLOW}Old version:${NC} $CURRENT_VERSION"
echo -e "  ${YELLOW}New version:${NC} $NEW_VERSION"
echo ""
echo "Don't forget to:"
echo "  1. Commit the version change"
echo "  2. Update CHANGELOG.md"
echo "  3. Create a release tag"
