# Scripts

Shell utilities grouped by purpose. **Platform folders** (`android/`, `ios/`, …) are not modified by these scripts unless noted.

## `scripts/dev/`

| Script | Purpose |
|--------|---------|
| [`format_dart.sh`](dev/format_dart.sh) | Format only `lib`, `test`, `integration_test`, `tool`, `bricks` (avoids scanning `build/`). Use `--check` for CI-style verification. |
| [`audit_template.sh`](dev/audit_template.sh) | Full non-platform gate: format check, `flutter analyze`, `flutter test`. |
| [`setup_git_hooks.sh`](dev/setup_git_hooks.sh) | Copy `.githooks/*` → `.git/hooks/` (single source of truth in repo). |
| [`setup_branding.sh`](dev/setup_branding.sh) | Splash / launcher assets (see root README). |
| [`create_feature.sh`](dev/create_feature.sh) | Scaffold a new feature slice under `lib/features/`. |

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
