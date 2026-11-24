#!/usr/bin/env bash
# Usage: manual_recipe_check.sh <fork-and-customize.md> <label>
# Clones origin/main into a scratch dir, runs section 2 of the given guide
# (extracted the way scripts-smoke.yml's manual-rename job does, minus
# `flutter gen-l10n`) with APPLE_ID=com.example.myApp, and prints every iOS
# and macOS bundle-id site plus the Android ids.
set -euo pipefail
doc=$1; label=$2
work=$(mktemp -d)
git clone -q --no-hardlinks /Users/nguyenanhkiet/Playground/flutter-starter "$work/repo"
cd "$work/repo"
git checkout -q origin/main 2>/dev/null || git checkout -q main
awk "/^export NAME='My App'/{f=1} f{print} f&&/^flutter gen-l10n\$/{exit}" "$doc" \
  | sed 's/^export APPLE_ID=.*/export APPLE_ID=com.example.myApp/; s/^export ANDROID_ID=.*/export ANDROID_ID=com.acme.shop/; /^flutter gen-l10n$/d' > "$work/section2.sh"
echo "== $label: section 2 as run =="; grep -n 'export\|com\\\\.example' "$work/section2.sh"
bash -euo pipefail "$work/section2.sh"
echo "== $label: bundle-id sites =="
grep -n 'PRODUCT_BUNDLE_IDENTIFIER' ios/Runner.xcodeproj/project.pbxproj macos/Runner.xcodeproj/project.pbxproj macos/Runner/Configs/AppInfo.xcconfig
grep -n -A1 'provisioningProfiles' ios/ExportOptions.plist | tail -1; grep -n -A2 'provisioningProfiles' ios/ExportOptions.plist | tail -1
grep -n '^app_identifier\|^package_name' ios/fastlane/Appfile fastlane/Appfile
grep -n 'APPLICATION_ID "' linux/CMakeLists.txt
grep -n 'PRODUCT_COPYRIGHT' macos/Runner/Configs/AppInfo.xcconfig
grep -n 'CompanyName\|LegalCopyright' windows/runner/Runner.rc
rm -rf "$work"
