# Scripts

Shell utilities grouped by purpose. **Platform folders** (`android/`, `ios/`, …) are not modified by these scripts unless noted.

## `scripts/dev/`

| Script | Purpose |
|--------|---------|
| [`format_dart.sh`](dev/format_dart.sh) | Format only `lib`, `test`, `integration_test`, `tool`, `examples` (avoids scanning `build/`). Use `--check` for CI-style verification, or `--print-paths` to read the scope. Not `bricks/`: it holds Mason templates whose mustache is not valid Dart, so `dart format` exits 65 on it. |
| [`audit_template.sh`](dev/audit_template.sh) | Full non-platform gate: env asset guard, generated code up to date (`AUDIT_SKIP_CODEGEN=1` skips it), format check, `flutter analyze`, `flutter test`. The script header lists what the CI Quality gate adds. |
| [`setup_git_hooks.sh`](dev/setup_git_hooks.sh) | Point this repository's `core.hooksPath` at `.githooks/`, so the committed hooks run in place (nothing is copied into `.git/hooks/`). Refuses, and says so, when `core.hooksPath` already points elsewhere. |
| [`setup_branding.sh`](dev/setup_branding.sh) | Splash / launcher assets (see root README). |
| [`create_feature.sh`](dev/create_feature.sh) | Scaffold a feature slice under `lib/features/<name>/` plus its mirrored test under `test/features/<name>/`. Output passes `flutter analyze` and `dart format --set-exit-if-changed` as generated. |
| [`create_feature.ps1`](dev/create_feature.ps1) | Windows equivalent of `create_feature.sh`. Writes byte-identical files (LF, UTF-8 without BOM); the parity is checked by the `scaffold-parity` job in [`scripts-smoke.yml`](../.github/workflows/scripts-smoke.yml). |
| [`setup_ci.dart`](dev/setup_ci.dart) | Uncomment the `push:` / `pull_request:` triggers inside each workflow's top-level `on:` block. `--dry-run` shows what it would change; `--yes` skips the prompt. The `deploy-*` workflows stay manual-only unless you pass `--deploy-trigger=tags` (deploy on version tags) or `--deploy-trigger=branch` (deploy on every push to main); exactly that one option is enabled. |

## `scripts/ci/`

| Script | Purpose |
|--------|---------|
| [`build_all.sh`](ci/build_all.sh) | Android + iOS (macOS only) + Web build for one `ENVIRONMENT`. No `--flavor`: this project has no Gradle product flavors and configures itself through `--dart-define`. Needs `API_SSL_FINGERPRINTS` (or `ENABLE_SSL_PINNING=false`) in the environment, or it refuses before building. |
| [`ssl_pinning_defines.sh`](ci/ssl_pinning_defines.sh) | Sourced by every mobile release build: turns `API_SSL_FINGERPRINTS` / `ENABLE_SSL_PINNING` into `--dart-define` arguments, and refuses a staging or production build that has neither. |
| [`bump_version.sh`](ci/bump_version.sh) | Bump `version:` in `pubspec.yaml`. Handles both `1.0.0` and `1.0.0+1`, validates before writing, and leaves the file untouched on any error. |
| [`generate_changelog.sh`](ci/generate_changelog.sh) | Build a CHANGELOG section from the commits since the last reachable tag, or since `--since <ref>`. Inserts it below `## [Unreleased]`, and refuses rather than dumping the whole history when no tag is reachable. No `sed -i`, so it behaves the same on GNU and BSD userlands. |
| [`release.sh`](ci/release.sh) | Test, analyze, bump, changelog, branch, tag. If the bump or the changelog step fails it restores `pubspec.yaml` and `CHANGELOG.md`, so the tree is left as it started. For a first release with no tag, set `RELEASE_CHANGELOG_SINCE=<ref>`. |
| [`verify_apk_signer.sh`](ci/verify_apk_signer.sh) | Assert an APK is signed by a non-debug key. Matches the `certificate DN:` *value*, not apksigner's scheme label (`Signer #1`, `V2 Signer:`, `V3 Signer:`, ...), and requires `Number of signers` >= 1. Used by the `Print APK signer certificate` step in [`build.yml`](../.github/workflows/build.yml). |

## `scripts/test/`

| Script | Purpose |
|--------|---------|
| [`test_coverage.sh`](test/test_coverage.sh) | Coverage reports (HTML, thresholds). |
| [`calculate_layer_coverage.sh`](test/calculate_layer_coverage.sh) | Layer breakdown (used by CI). |
| [`run_e2e_tests.sh`](test/run_e2e_tests.sh) | Run Patrol integration tests. |
| [`release_scripts_test.sh`](test/release_scripts_test.sh) | Fixture-repo tests for `generate_changelog.sh` and `release.sh`. Needs no Flutter. Run in CI on Ubuntu and macOS by [`release-scripts.yml`](../.github/workflows/release-scripts.yml) - automatically only in the template repository, by hand (Actions tab) in a project created from it. |
| [`format_check_test.sh`](test/format_check_test.sh) | Tests the format check the hooks and CI share. |
| [`test_coverage.ps1`](test/test_coverage.ps1) | `test_coverage.sh` for Windows PowerShell. |
| [`pre_commit_hook_test.sh`](test/pre_commit_hook_test.sh) | Runs the real `.githooks/pre-commit` in a fresh local clone: before `flutter pub get` it must refuse and rewrite nothing; after, pass a clean tree, ignore a format violation that is only in the working copy, and fail one that is staged. Needs Flutter. Run in CI by [`git-hooks.yml`](../.github/workflows/git-hooks.yml) - automatically only in the template repository, by hand (Actions tab) in a project created from it. |

## Conventions

- Prefer `bash` / `#!/usr/bin/env bash` with `set -euo pipefail` where used.
- Keep behavior aligned with [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) (format paths, analyze, test).
- Store release automation is documented under [`docs/deployment/`](../docs/deployment/README.md) (workflows + Fastlane).
