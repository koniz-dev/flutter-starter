# Tool (Dart)

Maintenance utilities run with `dart run` from the **repository root**.

## `strip_sample_features.dart`

Removes sample **`tasks`** and **`feature_flags`** modules (and related tests), deletes `lib/core/feature_flags/feature_flags_manager.dart` when present, and **copies rewired sources from `tool/golden/stripped/`** (mirrors `lib/`, `test/`, `integration_test/`). Keeps **auth** and core infrastructure.

Guards: after file operations the script scans `lib/`, `test/`, `integration_test/`, and `examples/` for leftover imports of the removed modules and exits with code **3** if any remain.

```bash
dart run tool/strip_sample_features.dart --apply
flutter pub get
flutter analyze
flutter test
```

### Golden tree

Edit **`tool/golden/stripped/`** when the stripped baseline should change (e.g. new `AppRoutes`, `main` bootstrap). Mirrored paths include `lib/`, `test/core/routing/` (`app_router_test.dart`, `app_routes_test.dart`), and `integration_test/`. The tree is **excluded from** `flutter analyze` via `analysis_options.yaml` so it does not conflict with the real `lib/`.

CI runs **Strip smoke** (`.github/workflows/strip-smoke.yml`): apply strip on a fresh checkout, then `flutter analyze` and `flutter test`.

See also [Fork and customize](../docs/guides/onboarding/fork-and-customize.md), [Contracts map](../docs/architecture/contracts-map.md) (stripped vs full starter), and the Mason brick under [`bricks/`](../bricks/).

## After stripping

- **Patrol:** Golden `integration_test/` targets **auth → home** (`#e2e_home_content` on `HomeScreen`). Run `patrol test --target integration_test/app_e2e_test.dart` after strip.
- Re-run **`flutter analyze`** and **`flutter test`**; the script’s guard should catch most stale imports.
