# Criterion 6: integration_test/README.md documents the gate

## Stable selectors

Do not rely on translated button labels for critical steps. Use `ValueKey`s from [`lib/core/constants/ui_keys.dart`](../lib/core/constants/ui_keys.dart) (e.g. `e2e_login_submit`, `e2e_home_content`).

Each file here holds **two** tests:

1. **A smoke test that always runs** — the app boots to a usable login screen. No backend needed. It is not a token test: reaching a rendered login screen exercises the native Patrol harness, app bootstrap, the Riverpod scope, the router, and localization.
2. **The authenticated flow, skipped by default** — everything past login. The sample auth flow POSTs to `BASE_URL`; with no server the login call fails, the app stays on the login screen, and those assertions are unreachable. Rather than ship a suite that is red by construction, they are gated:

```bash
# skipped (default) — the suite is green on a fresh clone
patrol test --target integration_test/app_e2e_test.dart

# run the authenticated flow, once you have an API reachable from the device
patrol test --target integration_test/app_e2e_test.dart --dart-define=E2E_BACKEND=true
```

A skipped test still appears in the summary (`⏩ Skipped: 1`), so it cannot be quietly forgotten.

**There is no tasks coverage, on purpose.** `UiKeys.openTasks`, `UiKeys.tasksFab`, and `UiKeys.addTaskSubmit` are declared but attached to no widget in `lib/`: `HomeScreen` is a deliberately minimal shell with no entry point into the sample `tasks` feature. Patrol matches on the widget tree, so a selector written against an unattached key finds nothing — attach the key first if your fork adds that entry point. `tool/golden/no_feature_flags/` shows the wiring, and its own `app_e2e_test.dart` does drive the full tasks flow.

**After** `dart run tool/strip_sample_features.dart --apply`, golden files replace these E2E files outright, so the post-strip variant is whatever `tool/golden/<variant>/integration_test/` contains — editing the copies here does not affect it.

## CI
