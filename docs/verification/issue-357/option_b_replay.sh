#!/bin/bash
# Applies docs/guides/onboarding/fork-and-customize.md "Option B - Manual"
# (as rewritten for koniz-dev/flutter-starter#357) to a fresh checkout and
# reports what is left. Run from the root of a throwaway checkout of main.
set -u
NEW=my_app
echo "\$ sed -i '' 's/^name: flutter_starter\$/name: $NEW/' pubspec.yaml   # step 1"
sed -i '' "s/^name: flutter_starter\$/name: $NEW/" pubspec.yaml; grep -n '^name:' pubspec.yaml
echo "\$ git grep -lz 'package:flutter_starter/' -- lib test integration_test tool examples bricks/feature_clean scripts/dev/create_feature.sh scripts/dev/create_feature.ps1 'docs/*.dart' | xargs -0 perl -pi -e ...   # step 2"
git grep -lz 'package:flutter_starter/' -- lib test integration_test tool \
  examples bricks/feature_clean scripts/dev/create_feature.sh \
  scripts/dev/create_feature.ps1 'docs/*.dart' \
  | xargs -0 perl -pi -e "s#package:flutter_starter/#package:${NEW}/#g"
echo "\$ flutter pub get; dart fix --apply --code=directives_ordering   # step 3"
flutter pub get > /dev/null 2>&1; echo "pub get exit=$?"
dart fix --apply --code=directives_ordering 2>&1 | tail -1
echo "\$ flutter analyze"
flutter analyze 2>&1 | tail -1; echo "analyze exit=${PIPESTATUS[0]}"
echo "\$ git grep -n 'package:flutter_starter/' -- '*.dart' '*.sh' '*.ps1'   # residue"
git grep -n 'package:flutter_starter/' -- '*.dart' '*.sh' '*.ps1' | cut -d: -f1 | sort | uniq -c
echo "\$ ./scripts/dev/create_feature.sh probe; flutter analyze lib/features/probe test/features/probe"
./scripts/dev/create_feature.sh probe > /dev/null 2>&1; echo "create_feature exit=$?"
flutter analyze lib/features/probe test/features/probe 2>&1 | grep -E '•|issues? found|No issues'
