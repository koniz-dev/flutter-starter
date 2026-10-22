#!/usr/bin/env bash

# Changelog generation script for Flutter Starter
# Usage: ./scripts/ci/generate_changelog.sh [version] [--since <ref>]
#
#   version        Defaults to the version in pubspec.yaml (build number
#                  dropped).
#   --since <ref>  Take commits in <ref>..HEAD. Without it the range starts at
#                  the most recent tag reachable from HEAD, and with no such
#                  tag the script refuses rather than dumping the whole
#                  history into one section.
#
# The new section goes directly below `## [Unreleased]` when that heading
# exists, otherwise above the first `## [<version>]` heading, otherwise at the
# end of the file. The insertion is done with awk into a temp file that is
# moved into place only once complete, so it does not depend on the GNU/BSD
# `sed -i` split (the BSD branch used to abort with `invalid command code`,
# and the GNU branch inserted after line 1).

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 [version] [--since <ref>]" >&2
}

VERSION=""
SINCE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --since)
            if [ $# -lt 2 ] || [ -z "$2" ]; then
                echo -e "${RED}Error: --since needs a ref${NC}" >&2
                usage
                exit 2
            fi
            SINCE="$2"
            shift 2
            ;;
        --since=*)
            SINCE="${1#--since=}"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo -e "${RED}Error: unknown option '$1'${NC}" >&2
            usage
            exit 2
            ;;
        *)
            if [ -n "$VERSION" ]; then
                echo -e "${RED}Error: more than one version given${NC}" >&2
                usage
                exit 2
            fi
            VERSION="$1"
            shift
            ;;
    esac
done

if [ -z "$VERSION" ]; then
    VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //' | cut -d'+' -f1)
fi
if [ -z "$VERSION" ]; then
    echo -e "${RED}Error: no version given and none found in pubspec.yaml${NC}" >&2
    exit 2
fi

DATE=$(date +%Y-%m-%d)

if [ -n "$SINCE" ]; then
    if ! git rev-parse --verify --quiet "${SINCE}^{commit}" >/dev/null; then
        echo -e "${RED}Error: --since '$SINCE' is not a commit${NC}" >&2
        exit 2
    fi
    RANGE="${SINCE}..HEAD"
    echo -e "${GREEN}Generating changelog from $SINCE to HEAD${NC}"
else
    LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || true)
    if [ -z "$LAST_TAG" ]; then
        echo -e "${RED}Error: no tag is reachable from HEAD, so there is no" \
            "previous release to start from.${NC}" >&2
        echo "Pass the range explicitly, e.g.:" >&2
        echo "  $0 $VERSION --since <ref>" >&2
        echo "Taking every commit in the history would put all of them in" \
            "one release section." >&2
        exit 1
    fi
    RANGE="${LAST_TAG}..HEAD"
    echo -e "${GREEN}Generating changelog from $LAST_TAG to HEAD${NC}"
fi

COMMITS=$(git log --pretty=format:"%s" --no-merges "$RANGE")

# One bucket per section, in output order. Each holds "- message" lines.
SECTIONS=(Added Changed Fixed Security Performance Refactored Documentation Style Tests Chore "CI/CD" Build Reverted)
declare -a BUCKETS
for i in "${!SECTIONS[@]}"; do BUCKETS[$i]=""; done

section_index() {
    case "$1" in
        feat*) echo 0 ;;
        fix*) echo 2 ;;
        security*) echo 3 ;;
        perf*) echo 4 ;;
        refactor*) echo 5 ;;
        docs*) echo 6 ;;
        style*) echo 7 ;;
        test*) echo 8 ;;
        chore*) echo 9 ;;
        ci*) echo 10 ;;
        build*) echo 11 ;;
        revert*) echo 12 ;;
        *) echo 1 ;; # Unknown types count as changes
    esac
}

while IFS= read -r commit; do
    [ -z "$commit" ] && continue
    TYPE=$(printf '%s' "$commit" | cut -d':' -f1 | cut -d'(' -f1 | tr '[:upper:]' '[:lower:]')
    MESSAGE=$(printf '%s' "$commit" | cut -d':' -f2- | sed 's/^ *//')
    idx=$(section_index "$TYPE")
    BUCKETS[$idx]="${BUCKETS[$idx]}- ${MESSAGE}"$'\n'
done <<< "$COMMITS"

ENTRY_FILE=$(mktemp)
# Same directory as CHANGELOG.md, so the final mv is a rename, never a copy.
OUT_FILE=$(mktemp "CHANGELOG.md.XXXXXX")
trap 'rm -f "$ENTRY_FILE" "$OUT_FILE"' EXIT

{
    printf '## [%s] - %s\n\n' "$VERSION" "$DATE"
    for i in "${!SECTIONS[@]}"; do
        if [ -n "${BUCKETS[$i]}" ]; then
            printf '### %s\n\n%s\n' "${SECTIONS[$i]}" "${BUCKETS[$i]}"
        fi
    done
} > "$ENTRY_FILE"

if [ ! -f "CHANGELOG.md" ]; then
    echo -e "${YELLOW}Creating CHANGELOG.md${NC}"
    cat > CHANGELOG.md << 'HEADER'
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

HEADER
fi

# Insert before the first `## [` heading that is not `## [Unreleased]`, which
# puts the new section below an Unreleased section and above the newest
# release. With no such heading, append.
awk -v entry_file="$ENTRY_FILE" '
    function emit_entry(   line) {
        while ((getline line < entry_file) > 0) print line
        close(entry_file)
        done = 1
    }
    !done && /^## \[/ && $0 !~ /^## \[Unreleased\]/ { emit_entry() }
    { print }
    END {
        if (!done) {
            print ""
            emit_entry()
        }
    }
' CHANGELOG.md > "$OUT_FILE"

chmod 644 "$OUT_FILE"
mv "$OUT_FILE" CHANGELOG.md

echo -e "${GREEN}Changelog generated successfully!${NC}"
echo -e "  ${YELLOW}Version:${NC} $VERSION"
echo -e "  ${YELLOW}Date:${NC} $DATE"
echo -e "  ${YELLOW}Range:${NC} $RANGE"
echo ""
echo "Review CHANGELOG.md and commit if satisfied."
