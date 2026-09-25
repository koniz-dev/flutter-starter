# Tool (Dart)

Maintenance utilities run with `dart run` from the **repository root**.

## `check_docs.dart`

Documentation integrity checker. Three checks, all of which had silently rotted:

- **Links and anchors** under `docs/`: every relative path resolves, and every
  `#fragment` matches a heading slug in the target file (GitHub's slug rules,
  including duplicate `-1` suffixes).
- **Emoji** in `docs/`, `CLAUDE.md` and `.claude/`, per the convention stated in
  `CLAUDE.md`. `README.md` and `CONTRIBUTING.md` are exempt (they predate it), and
  so is `docs/verification/`, whose files quote captured tool output verbatim.
- **Constructor signatures** (`doc_signatures.dart`): any fenced block preceded
  by `<!-- signature: <source path> <ConstructorName> -->` must list exactly the
  named parameters that constructor declares, in order, with the same types,
  `required` markers and defaults. Added after koniz-dev/flutter-starter#89,
  where `docs/api/core/network.md` documented an `AuthInterceptor` parameter
  that never existed while missing three that did.

```bash
dart run tool/check_docs.dart               # all checks
dart run tool/check_docs.dart --links       # links and anchors only
dart run tool/check_docs.dart --emoji       # emoji only
dart run tool/check_docs.dart --signatures  # constructor signatures only
```

Exits 1 and prints `file:line` for every problem. CI runs it as **Docs check**
(`.github/workflows/docs-check.yml`) on any PR touching markdown - exactly the
set of changes the Quality gate treats as inert and skips. The signature check
additionally runs under `flutter test` (`test/docs/doc_signatures_test.dart`),
because a constructor gaining a parameter is a `lib/` change that Docs check
never sees. It is deliberately
**not** part of `scripts/dev/audit_template.sh`: that script gates code changes,
and a broken doc link should not block an unrelated `lib/` fix.

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
