# Scripts

Shell utilities grouped by purpose. **Platform folders** (`android/`, `ios/`, …) are not modified by these scripts unless noted.

## `scripts/dev/`

| Script | Purpose |
|--------|---------|
| [`format_dart.sh`](dev/format_dart.sh) | Format only `lib`, `test`, `integration_test`, `tool`, `examples` (avoids scanning `build/`). Use `--check` for CI-style verification, or `--print-paths` to read the scope. Not `bricks/`: it holds Mason templates whose mustache is not valid Dart, so `dart format` exits 65 on it. |
| [`audit_template.sh`](dev/audit_template.sh) | Full non-platform gate: format check, `flutter analyze`, `flutter test`. |
| [`setup_git_hooks.sh`](dev/setup_git_hooks.sh) | Copy `.githooks/*` → `.git/hooks/` (single source of truth in repo). |
| [`setup_branding.sh`](dev/setup_branding.sh) | Splash / launcher assets (see root README). |
| [`create_feature.sh`](dev/create_feature.sh) | Scaffold a feature slice under `lib/features/<name>/` plus its mirrored test under `test/features/<name>/`. Output passes `flutter analyze` and `dart format --set-exit-if-changed` as generated. |
| [`create_feature.ps1`](dev/create_feature.ps1) | Windows equivalent of `create_feature.sh`. Writes byte-identical files (LF, UTF-8 without BOM); the parity is checked by the `scaffold-parity` job in [`scripts-smoke.yml`](../.github/workflows/scripts-smoke.yml). |
| [`setup_ci.dart`](dev/setup_ci.dart) | Uncomment the `push:` / `pull_request:` triggers inside each workflow's top-level `on:` block. `--dry-run` shows what it would change; `--yes` skips the prompt. |

## `scripts/ci/`

| Script | Purpose |
|--------|---------|
| [`build_all.sh`](ci/build_all.sh) | Android + iOS (macOS only) + Web build for one `ENVIRONMENT`. No `--flavor`: this project has no Gradle product flavors and configures itself through `--dart-define`. |
| [`bump_version.sh`](ci/bump_version.sh) | Bump `version:` in `pubspec.yaml`. Handles both `1.0.0` and `1.0.0+1`, validates before writing, and leaves the file untouched on any error. |
| [`generate_changelog.sh`](ci/generate_changelog.sh) | Build a CHANGELOG section from the commit log. |
| [`release.sh`](ci/release.sh) | Test, analyze, bump, changelog, branch, tag. |

## `scripts/test/`

| Script | Purpose |
|--------|---------|
| [`test_coverage.sh`](test/test_coverage.sh) | Coverage reports (HTML, thresholds). |
| [`calculate_layer_coverage.sh`](test/calculate_layer_coverage.sh) | Layer breakdown (used by CI). |
| [`run_e2e_tests.sh`](test/run_e2e_tests.sh) | Run Patrol integration tests. |

## Conventions

- Prefer `bash` / `#!/usr/bin/env bash` with `set -euo pipefail` where used.
- Keep behavior aligned with [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) (format paths, analyze, test).
- Store release automation is documented under [`docs/deployment/`](../docs/deployment/README.md) (workflows + Fastlane).
