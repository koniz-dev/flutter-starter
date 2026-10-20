#!/usr/bin/env bash
# Usage: repro330.sh <repo-root>. Builds scratch pubspecs, runs the guard on each.
set -u
REPO="$1"; W="$(mktemp -d)"
mk() { mkdir -p "$W/$1"; printf '%s\n' "name: scratch" "flutter:" "  assets:" "$2" > "$W/$1/pubspec.yaml"; printf 'SECRET=1\n' > "$W/$1/.env"; }
mk a "    - path: .env"
mk b "    [.env.example, .env]"; printf '%s\n' "name: scratch" "flutter:" "  assets: [.env.example, .env]" > "$W/b/pubspec.yaml"
mk c "    - path: assets/config/"; mkdir -p "$W/c/assets/config"; printf 'SECRET=1\n' > "$W/c/assets/config/.env"
mk d "    - assets/config/"; mkdir -p "$W/d/assets/config"; printf 'SECRET=1\n' > "$W/d/assets/config/.env"
mk e "    - path: .env # env-asset-ack: web build, contains no secrets"
mk f "    - flavors: [web]"; printf '%s\n' "name: scratch" "flutter:" "  assets:" "    - flavors: [web]" "      path: .env" > "$W/f/pubspec.yaml"
mk g ""; printf '%s\n' "name: scratch" "flutter:" "  assets:" "    - .env" "   bad: [" > "$W/g/pubspec.yaml"
for c in a b c d e f g; do
  line="$(sed -n '3,5p' "$W/$c/pubspec.yaml" | tr '\n' '|')"
  (cd "$REPO" && dart run tool/check_env_assets.dart "$W/$c/pubspec.yaml" >/dev/null 2>"$W/$c.err"); rc=$?
  printf 'case %s  exit=%s  %s\n' "$c" "$rc" "$line"
done
rm -rf "$W"
