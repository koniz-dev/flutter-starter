#!/usr/bin/env bash
# Follows fork-and-customize Option B (section 1) and section 2 to my_app /
# "My App" on a clean copy of REV, running section 2's command block exactly
# as the guide prints it, then the guide's own leftover check, analyze and test.
set -uo pipefail
repo=$1; rev=$2; dir=$3
git -C "$repo" worktree add -q --detach "$dir" "$rev"
cd "$dir"
doc=docs/guides/onboarding/fork-and-customize.md
echo "# $(git rev-parse --short HEAD)"
# Section 1, Option B.
perl -pi -e 's/^name: flutter_starter$/name: my_app/' pubspec.yaml
git grep -lz 'package:flutter_starter/' -- lib test integration_test tool \
  examples bricks/feature_clean scripts/dev/create_feature.sh \
  scripts/dev/create_feature.ps1 'docs/*.dart' \
  | xargs -0 perl -pi -e 's#package:flutter_starter/#package:my_app/#g'
flutter pub get >/dev/null 2>&1
dart fix --apply --code=directives_ordering >/dev/null 2>&1
# Section 2, extracted from the guide.
awk "/^export NAME='My App'/{f=1} f{print} f&&/^flutter gen-l10n\$/{exit}" "$doc" > "$dir/../section2.sh"
echo '## section 2 as extracted:'; cat "$dir/../section2.sh"
bash -euo pipefail "$dir/../section2.sh"; echo "section 2 exit: $?"
echo '## leftover check (prints nothing when clean):'
awk "/^git grep -n -i -e 'flutter starter'/{f=1} f{print} f&&/# prints nothing\$/{exit}" "$doc" > "$dir/../leftovers.sh"
cat "$dir/../leftovers.sh"
bash "$dir/../leftovers.sh"
echo "grep exit: $? (1 = nothing found)"
echo '## git status --short | head'; git status --short | head -60
flutter pub get >/dev/null 2>&1
flutter analyze 2>&1 | tail -1
flutter test --timeout=5m 2>&1 | tail -1
