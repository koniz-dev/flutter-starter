# Repository layout (non-platform)

This document describes **template-owned directories** only. Flutter **platform** trees (`android/`, `ios/`, `linux/`, `macos/`, `web/`, `windows/`) and generated folders (`build/`, `.dart_tool/`) are excluded here; see platform docs when changing bundle IDs, flavors, or signing.

## Top-level map

| Path | Role |
|------|------|
| [`lib/`](../../../lib/) | Application code: `core/`, `features/`, `shared/`, `l10n/`, `main.dart`. |
| [`test/`](../../../test/) | Unit, widget, and in-repo integration tests; mirrors `lib/` structure. |
| [`integration_test/`](../../../integration_test/) | Patrol E2E tests; uses stable keys in [`lib/core/constants/ui_keys.dart`](../../../lib/core/constants/ui_keys.dart). |
| [`docs/`](../../) | Architecture, guides, API notes. Start at [docs/README.md](../../README.md). |
| [`scripts/`](../../../scripts/) | Shell automation: `dev/` (hooks, format, features), `test/` (coverage, E2E). Index: [scripts/README.md](../../../scripts/README.md). |
| [`tool/`](../../../tool/) | Dart maintenance scripts (e.g. strip sample features). |
| [`examples/`](../../../examples/) | Non-shipping Dart snippets; see [`examples/README.md`](../../../examples/README.md). |
| [`bricks/`](../../../bricks/) | Optional [Mason](https://pub.dev/packages/mason_cli) brick(s) for fork setup (rename package / native ids); see [`bricks/README.md`](../../../bricks/README.md) and [`mason.yaml`](../../../mason.yaml). Safe to delete **`bricks/`** + **`mason.yaml`** if you rename manually and do not use Mason. |
| [`.github/workflows/`](../../../.github/workflows/) | CI, optional manual E2E, deploy templates. |
| [`.githooks/`](../../../.githooks/) | Canonical hook scripts in repo; [`setup_git_hooks.sh`](../../../scripts/dev/setup_git_hooks.sh) copies them to `.git/hooks/`. |

## `lib/` structure

```
lib/
├── core/           # Config, DI, network, storage, routing, security, contracts, adapters
├── features/       # Vertical slices: auth, home, tasks, feature_flags, …
├── shared/         # Cross-feature UI, theme, design_system, widgets
├── l10n/           # Generated/localization
└── main.dart
```

- **Swap points:** see [Contracts and adapter map](../../architecture/contracts-map.md).
- **Fork workflow:** [Fork and customize](fork-and-customize.md).

## `test/` structure

Mirrors `lib/features/*` and `lib/core/*` where practical. Shared helpers live under `test/helpers/`. Details: [test/README.md](../../../test/README.md).

## Related

- [Super starter hub](../../architecture/super-starter-hub.md)
- [Choose your stack](../../architecture/choose-your-stack.md)
