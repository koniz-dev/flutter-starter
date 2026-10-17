#!/usr/bin/env bash
# Evidence probe for koniz-dev/flutter-starter#339, run from the repo root.
#
# Copies the repository to a scratch directory, brands it with an RGBA logo
# (web/favicon.png, which has an alpha channel), runs the real
# flutter_launcher_icons, and reports the PNG colour type of the generated
# iOS 1024 icon: byte 25 of a PNG is the IHDR colour type, 2 = RGB,
# 6 = RGBA. App Store Connect rejects 6.
#
# Usage: docs/verification/issue-339/alpha_probe.sh [path/to/flutter_launcher_icons.yaml]
set -euo pipefail
CONFIG="${1:-flutter_launcher_icons.yaml}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
git ls-files -z | rsync -a --from0 --files-from=- ./ "$WORK/"
cp "$CONFIG" "$WORK/flutter_launcher_icons.yaml"
cd "$WORK"
colortype() { od -An -tu1 -j25 -N1 "$1" | tr -d ' '; }
cp web/favicon.png assets/images/logo.png
echo "logo colour type: $(colortype assets/images/logo.png)  (6 = RGBA)"
flutter pub get >/dev/null 2>&1
dart run flutter_launcher_icons 2>&1 | grep -iE "alpha|error|generat" || true
ICON=ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
TYPE=$(colortype "$ICON")
echo "iOS 1024 icon colour type: $TYPE  (2 = RGB, 6 = RGBA)"
[ "$TYPE" = "2" ]
