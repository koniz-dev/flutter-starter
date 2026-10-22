#!/usr/bin/env bash
# Rehearses the demo sign-in removal recipe (koniz-dev/flutter-starter#628)
# on a detached worktree of the given commit, then runs analyze and test.
set -euo pipefail
repo=$1; rev=$2; dir=$3
git -C "$repo" worktree add -q --detach "$dir" "$rev"
cd "$dir"
set -x
rm -rf lib/features/auth/demo test/features/auth/demo test/flutter_test_config.dart
git grep -n -e DemoAuth -e DemoSignInCard -e auth/demo lib || true
sed -i '' '/auth\/demo\//d;/DemoAuth.enabled) return/d' lib/features/auth/di/auth_providers.dart
python3 - <<'PY'
import re
p='lib/features/auth/presentation/screens/login_screen.dart'
s=open(p).read()
s=re.sub(r"import 'package:flutter_starter/features/auth/demo/[a-z_]+\.dart';\n","",s)
s=re.sub(r" *if \(DemoAuth\.enabled\) \.\.\.\[.*?\n *\],\n","",s,flags=re.S)
open(p,'w').write(s)
p='docs/guides/onboarding/getting-started.md'
s=open(p).read()
a=s.index('### Signing In Before You Have a Backend'); b=s.index('### Platform-Specific')
open(p,'w').write(s[:a]+s[b:])
PY
git grep -n -e DemoAuth -e DemoSignInCard -e auth/demo lib test docs || echo "no references left"
git diff --stat
set +x
flutter pub get >/dev/null
flutter analyze
flutter test --timeout=5m --reporter=expanded 2>&1 | tail -3
