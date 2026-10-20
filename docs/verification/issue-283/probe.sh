#!/usr/bin/env bash
# Usage: probe283.sh <repo> <before|after> <acme|default> <outdir> [test]
set -u
REPO="$1"; WHICH="$2"; ANSWERS="$3"; OUT="$4"; RUNTEST="${5:-}"
export PATH="$PATH:$HOME/.pub-cache/bin"
W="$(mktemp -d)/tree"; mkdir -p "$W"
git -C "$REPO" archive main | tar -x -C "$W"
if [ "$WHICH" = after ]; then cp "$REPO/bricks/flutter_starter_setup/hooks/post_gen.dart" "$W/bricks/flutter_starter_setup/hooks/post_gen.dart"; fi
cd "$W"
# An adopter's tree is a git checkout; epic_coverage_test reads `git ls-files`.
git init -q -b main && git add -A && git -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q -m "chore: template at main" --no-verify
LOG="$OUT/$WHICH-$ANSWERS.log"
{
  echo "# $WHICH hook ($( [ "$WHICH" = after ] && echo branch || echo "main $(git -C "$REPO" rev-parse --short main)")), answers: $ANSWERS"
  mason get >/dev/null 2>&1
  if [ "$ANSWERS" = acme ]; then
    echo '$ mason make flutter_starter_setup --package_name acme_shop --application_id com.acme.shop --ios_bundle_id com.acme.shop --app_display_name "Acme Shop" --strip_sample_features false --include_tasks_sample true --include_feature_flags_sample true --on-conflict overwrite'
    mason make flutter_starter_setup --package_name acme_shop --application_id com.acme.shop --ios_bundle_id com.acme.shop --app_display_name "Acme Shop" --strip_sample_features false --include_tasks_sample true --include_feature_flags_sample true --on-conflict overwrite 2>&1 | sed 's/\x1b\[[0-9;]*m//g'
  else
    echo '$ mason make flutter_starter_setup  # every value = the default in brick.yaml'
    echo '    --package_name my_app --application_id com.example.my_app --ios_bundle_id com.example.myApp --app_display_name "My App" --strip_sample_features false --include_tasks_sample true --include_feature_flags_sample true --on-conflict overwrite'
    mason make flutter_starter_setup --package_name my_app --application_id com.example.my_app --ios_bundle_id com.example.myApp --app_display_name "My App" --strip_sample_features false --include_tasks_sample true --include_feature_flags_sample true --on-conflict overwrite 2>&1 | sed 's/\x1b\[[0-9;]*m//g'
  fi
  echo "mason exit=${PIPESTATUS[0]}"
  echo '$ flutter pub get && flutter analyze'
  flutter pub get >/dev/null 2>&1; echo "pub get exit=$?"
  flutter analyze > analyze.out 2>&1; rc=$?
  tail -1 analyze.out; echo "analyze exit=$rc"
  echo "findings by rule:"; grep -oE "• [a-z_]+$" analyze.out | sort | uniq -c | sort -rn | head
  echo '$ grep -rl "package:flutter_starter/" docs | grep .dart$'; grep -rl "package:flutter_starter/" docs 2>/dev/null | grep '\.dart$' || echo "(none)"
  echo '$ grep -rn "Flutter Starter" lib --include=*.dart --include=*.arb'; grep -rn "Flutter Starter" lib --include='*.dart' --include='*.arb' | sed 's/^/  /' || true
  if [ -n "$RUNTEST" ]; then echo '$ flutter test --timeout=5m'; flutter test --timeout=5m 2>&1 | tail -1; echo "test exit=${PIPESTATUS[0]}"; fi
} > "$LOG" 2>&1
rm -rf "$(dirname "$W")"
