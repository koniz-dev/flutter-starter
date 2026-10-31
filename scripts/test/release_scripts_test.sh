#!/usr/bin/env bash

# Tests for scripts/ci/generate_changelog.sh and scripts/ci/release.sh against
# throwaway fixture repositories.
#
# Usage: ./scripts/test/release_scripts_test.sh
#
# Needs only bash, git and awk - no Flutter: release.sh's `flutter test` and
# `flutter analyze` steps run against a stub on PATH. CI runs this on both
# ubuntu-latest (GNU userland) and macos-latest (BSD userland, bash 3.2) in
# .github/workflows/release-scripts.yml, because the bug it guards was a
# GNU/BSD `sed -i` split that only ever showed up on one of the two.
#
# SCRIPTS_UNDER_TEST=<dir> points the tests at another copy of scripts/ci/,
# for example an older revision, to show a case fails there.
#
# Exits non-zero when any case fails.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPTS="${SCRIPTS_UNDER_TEST:-$ROOT/scripts/ci}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

FAILURES=0
pass() { echo "ok    $1"; }
fail() { echo "FAIL  $1"; FAILURES=$((FAILURES + 1)); }

git_q() { git -c user.email=test@example.com -c user.name=test -c commit.gpgsign=false -c tag.gpgsign=false "$@"; }

# A fixture repo whose CHANGELOG.md has this repository's layout: title,
# preamble, `## [Unreleased]` with content, then a released version.
new_repo() {
    local dir="$WORK/$1"
    mkdir -p "$dir/scripts/ci"
    cp "$SCRIPTS"/generate_changelog.sh "$SCRIPTS"/release.sh "$SCRIPTS"/bump_version.sh "$dir/scripts/ci/"
    cat > "$dir/CHANGELOG.md" <<'MD'
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Removed

- Something still unreleased.

## [1.0.0+1] - First release

### Added

- Everything.
MD
    printf 'name: fixture\nversion: 1.0.0+1\n' > "$dir/pubspec.yaml"
    (
        cd "$dir" || exit 1
        git init -q -b main
        git_q add -A
        git_q commit -q -m "chore: initial import"
    )
    echo "$dir"
}

commit_in() { (cd "$1" && git_q commit -q --allow-empty -m "$2"); }

headings() { grep -n '^## ' "$1/CHANGELOG.md" | sed 's/ - .*//' ; }

# --- 1. generate_changelog.sh after a tag: exit 0, section in the right place
repo=$(new_repo tagged)
(cd "$repo" && git_q tag v1.0.0)
commit_in "$repo" "feat(auth): add login"
commit_in "$repo" "fix: crash on start"
out=$(cd "$repo" && bash scripts/ci/generate_changelog.sh 1.2.3 2>&1); rc=$?
if [ $rc -eq 0 ]; then pass "generate_changelog.sh 1.2.3 exits 0"; else fail "generate_changelog.sh 1.2.3 exits 0 (got $rc: $out)"; fi
order=$(headings "$repo" | sed 's/^[0-9]*://' | tr '\n' '|')
expected='## [Unreleased]|## [1.2.3]|## [1.0.0+1]|'
if [ "$order" = "$expected" ]; then
    pass "the new section sits below Unreleased and above 1.0.0+1"
else
    fail "heading order: expected '$expected', got '$order'"
fi
if grep -q '^- add login$' "$repo/CHANGELOG.md" && grep -q '^- crash on start$' "$repo/CHANGELOG.md"; then
    pass "commits after the tag are listed"
else
    fail "commits after the tag are listed"
fi
if grep -q 'initial import' "$repo/CHANGELOG.md"; then
    fail "a commit before the tag leaked into the section"
else
    pass "commits before the tag are not listed"
fi
if grep -q '^- Something still unreleased.$' "$repo/CHANGELOG.md"; then
    pass "the Unreleased section is kept intact"
else
    fail "the Unreleased section is kept intact"
fi

# --- 2. no reachable tag: refuse and name --since; --since limits the range
repo=$(new_repo untagged)
base=$(cd "$repo" && git rev-parse HEAD)
commit_in "$repo" "feat: only this one"
before=$(cat "$repo/CHANGELOG.md")
out=$(cd "$repo" && bash scripts/ci/generate_changelog.sh 2.0.0 2>&1); rc=$?
if [ $rc -ne 0 ] && printf '%s' "$out" | grep -q -- '--since'; then
    pass "with no tag it refuses and names --since"
else
    fail "with no tag it refuses and names --since (exit $rc: $out)"
fi
if [ "$(cat "$repo/CHANGELOG.md")" = "$before" ]; then
    pass "a refused run leaves CHANGELOG.md untouched"
else
    fail "a refused run leaves CHANGELOG.md untouched"
fi
out=$(cd "$repo" && bash scripts/ci/generate_changelog.sh 2.0.0 --since "$base" 2>&1); rc=$?
if [ $rc -eq 0 ] && grep -q '^- only this one$' "$repo/CHANGELOG.md" && ! grep -q 'initial import' "$repo/CHANGELOG.md"; then
    pass "--since <ref> lists exactly the commits in <ref>..HEAD"
else
    fail "--since <ref> lists exactly the commits in <ref>..HEAD (exit $rc: $out)"
fi

# --- 3. no CHANGELOG.md at all: created, with the section
repo=$(new_repo fresh)
(cd "$repo" && git_q rm -q CHANGELOG.md && git_q commit -q -m "chore: drop changelog" && git_q tag v0.1.0)
commit_in "$repo" "feat: brand new"
out=$(cd "$repo" && bash scripts/ci/generate_changelog.sh 0.2.0 2>&1); rc=$?
if [ $rc -eq 0 ] && grep -q '^## \[0.2.0\]' "$repo/CHANGELOG.md" && grep -q '^- brand new$' "$repo/CHANGELOG.md"; then
    pass "a missing CHANGELOG.md is created with the section"
else
    fail "a missing CHANGELOG.md is created with the section (exit $rc: $out)"
fi

# --- 4. release.sh is transactional when generate_changelog.sh fails
repo=$(new_repo release)
cat > "$repo/scripts/ci/generate_changelog.sh" <<'SH'
#!/usr/bin/env bash
echo "stub: changelog generation fails" >&2
exit 1
SH
chmod +x "$repo/scripts/ci/"*.sh
(cd "$repo" && git_q add -A && git_q commit -q -m "chore: stub the changelog step")
mkdir -p "$WORK/bin"
printf '#!/usr/bin/env bash\nexit 0\n' > "$WORK/bin/flutter"
chmod +x "$WORK/bin/flutter"
out=$(cd "$repo" && PATH="$WORK/bin:$PATH" bash scripts/ci/release.sh patch < /dev/null 2>&1); rc=$?
status=$(cd "$repo" && git status --short)
if [ $rc -ne 0 ]; then pass "release.sh fails when the changelog step fails"; else fail "release.sh fails when the changelog step fails"; fi
if [ -z "$status" ]; then
    pass "after the failure git status --short is empty"
else
    fail "after the failure git status --short is empty, got: $(printf '%s' "$status" | tr '\n' ' ')"
fi
branch=$(cd "$repo" && git rev-parse --abbrev-ref HEAD)
tags=$(cd "$repo" && git tag)
if [ "$branch" = "main" ] && [ -z "$tags" ]; then
    pass "no release branch or tag was created"
else
    fail "no release branch or tag was created (branch=$branch tags=$tags)"
fi

# --- 5. release.sh stops before changing anything when the branch or tag exists
for existing in "tag v1.0.1" "branch release/v1.0.1"; do
    repo=$(new_repo "exists-${existing%% *}")
    # A previous release, so that without the check the run gets as far as
    # step 5 or 7 with pubspec.yaml and CHANGELOG.md already rewritten.
    (cd "$repo" && git_q tag v1.0.0 && git_q commit -q --allow-empty -m "feat: something new" && git_q $existing)
    head_before=$(cd "$repo" && git rev-parse HEAD)
    out=$(cd "$repo" && PATH="$WORK/bin:$PATH" bash scripts/ci/release.sh patch < /dev/null 2>&1); rc=$?
    status=$(cd "$repo" && git status --short)
    branch=$(cd "$repo" && git rev-parse --abbrev-ref HEAD)
    head_after=$(cd "$repo" && git rev-parse HEAD)
    if [ $rc -ne 0 ] && [ -z "$status" ] && [ "$branch" = "main" ] && [ "$head_before" = "$head_after" ] \
        && printf '%s' "$out" | grep -q "already exists. Nothing was changed"; then
        pass "an existing ${existing%% *} stops release.sh with a clean tree"
    else
        fail "an existing ${existing%% *} stops release.sh with a clean tree (exit $rc, branch $branch, status: $(printf '%s' "$status" | tr '\n' ' '))"
    fi
    if printf '%s' "$out" | grep -q "Step 1"; then
        fail "an existing ${existing%% *} is caught before the tests run"
    else
        pass "an existing ${existing%% *} is caught before the tests run"
    fi
done

# --- 6. the summary claims an automatic deploy only when a tag trigger is live
summary() { # deploy-workflow-content -> release.sh output, push declined
    local repo
    repo=$(new_repo "summary-$RANDOM")
    if [ -n "$1" ]; then
        mkdir -p "$repo/.github/workflows"
        printf '%s\n' "$1" > "$repo/.github/workflows/deploy-web.yml"
        (cd "$repo" && git_q add -A && git_q commit -q -m "ci: deploy workflow")
    fi
    (cd "$repo" && git_q tag v1.0.0 && git_q commit -q --allow-empty -m "feat: something new")
    (cd "$repo" && printf 'n' | PATH="$WORK/bin:$PATH" bash scripts/ci/release.sh patch 2>&1)
}
out=$(summary "$(printf 'on:\n  workflow_dispatch:\n  # push:\n  #   tags:\n  #     - v*')")
if printf '%s' "$out" | grep -q "No deploy workflow runs on a tag yet" && ! printf '%s' "$out" | grep -q "automatically"; then
    pass "with the tag trigger commented out, the summary claims no deploy"
else
    fail "with the tag trigger commented out, the summary claims no deploy, got: $(printf '%s' "$out" | tail -8 | tr '\n' ' ')"
fi
out=$(summary "$(printf 'on:\n  push:\n    tags:\n      - v*')")
if printf '%s' "$out" | grep -q "The pushed tag starts the deploy workflows"; then
    pass "with a live tag trigger, the summary says the tag deploys"
else
    fail "with a live tag trigger, the summary says the tag deploys, got: $(printf '%s' "$out" | tail -8 | tr '\n' ' ')"
fi

# --- bump_version.sh keeps a trailing comment
bump_fixture() { # pubspec-version-line -> echoes the rewritten line
    local dir="$WORK/bump-$RANDOM"
    mkdir -p "$dir/scripts/ci"
    cp "$SCRIPTS"/bump_version.sh "$dir/scripts/ci/"
    printf 'name: fixture\n%s\ndescription: x\n' "$1" > "$dir/pubspec.yaml"
    (cd "$dir" && bash scripts/ci/bump_version.sh patch > /dev/null 2>&1) || echo "EXIT-FAILED"
    grep '^version:' "$dir/pubspec.yaml"
    grep -c '^description: x$' "$dir/pubspec.yaml" > /dev/null || echo "OTHER-LINE-CHANGED"
}
got=$(bump_fixture 'version: 1.2.3+4 # note')
if [ "$got" = 'version: 1.2.4+5 # note' ]; then
    pass "bump_version.sh patch keeps the version line's trailing comment"
else
    fail "bump_version.sh patch keeps the version line's trailing comment, got: $got"
fi
got=$(bump_fixture 'version: 1.2.3+4')
if [ "$got" = 'version: 1.2.4+5' ]; then
    pass "bump_version.sh patch on a line with no comment adds nothing"
else
    fail "bump_version.sh patch on a line with no comment adds nothing, got: $got"
fi
got=$(bump_fixture 'version: 1.2.3   # spaced  note')
if [ "$got" = 'version: 1.2.4   # spaced  note' ]; then
    pass "bump_version.sh keeps the comment's spacing exactly"
else
    fail "bump_version.sh keeps the comment's spacing exactly, got: $got"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
    echo "All release-script tests passed."
else
    echo "$FAILURES release-script test(s) failed."
fi
[ "$FAILURES" -eq 0 ]
