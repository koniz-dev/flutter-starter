# Integration tests (Patrol)

This directory sits at the **repository root** on purpose: that matches the [Flutter integration-test layout](https://docs.flutter.dev/testing/integration-tests) (`integration_test/` next to `lib/` and `test/`), not inside `lib/`.

End-to-end tests here drive a **real app** on a device or emulator (unlike `test/`, which runs on the host VM).

## Prerequisites

```bash
dart pub global activate patrol_cli 3.11.0
flutter pub get
```

## Running locally

From the repository root:

```bash
./scripts/test/run_e2e_tests.sh
```

Or target one file:

```bash
patrol test --target integration_test/app_e2e_test.dart
```

## Never use `pumpAndSettle` here

Use Patrol's `waitUntilVisible` instead. `pumpAndSettle` cannot work on a device, and this is not a quirk of this app.

`pumpAndSettle` is a `do { pump } while (binding.hasScheduledFrame)` loop ([`widget_tester.dart:721`](https://github.com/flutter/flutter/blob/stable/packages/flutter_test/lib/src/widget_tester.dart)). It exits only on a frame where nothing further is scheduled.

Patrol's `PatrolBinding` extends `LiveTestWidgetsFlutterBinding` (`patrol/lib/src/binding.dart:43`). In that binding, `handleDrawFrame` ends with:

```dart
} else if (framePolicy != LiveTestWidgetsFlutterBindingFramePolicy.benchmark) {
  platformDispatcher.scheduleFrame();
}
```

(`flutter_test/lib/src/binding.dart:2823-2825`)

The `else` branch is taken for every frame the test did not itself pump. On a device, vsync delivers those continuously, so each one schedules the next. A frame is therefore *always* pending, `hasScheduledFrame` is never false, and the loop cannot exit — it runs until the timeout and throws `pumpAndSettle timed out`, no matter how idle the app is.

The one policy that does not re-arm is `benchmark`, and `pumpAndSettle` explicitly rejects it (`widget_tester.dart:700-710`, "hasScheduledFrame is never set to true ... pumpAndSettle() cannot be used"). So there is no frame policy under which this works: either frames are always scheduled, or they are never scheduled.

This is upstream Flutter behaviour, deliberate for live bindings, and not something this repository can remove. The cost is only that device tests must poll instead of waiting for quiescence. **On the host VM (`flutter test`) `pumpAndSettle` is fine**, including on the full app — `test/main_test.dart` pumps `MyApp` and settles as a standing regression guard.

## Stable selectors

Do not rely on translated button labels for critical steps. Use `ValueKey`s from [`lib/core/constants/ui_keys.dart`](../lib/core/constants/ui_keys.dart) (e.g. `e2e_login_submit`, `e2e_home_content`).

Each file here holds **two** tests, and both run on a fresh clone:

1. **A smoke test** — the app boots to a usable login screen. It is not a token test: reaching a rendered login screen exercises the native Patrol harness, app bootstrap, the Riverpod scope, the router, and localization.
2. **The authenticated flow** — sign in, reach home. With no backend configured, the debug build Patrol runs signs in through the offline demo account (the login screen's demo card fills it), so no server is needed. Built with a `BASE_URL`, the demo is off and the test sends the sample credentials to that API instead, which must accept them:

```bash
# no backend: signs in through the demo account
patrol test --target integration_test/app_e2e_test.dart

# against your API, reachable from the device
patrol test --target integration_test/app_e2e_test.dart --dart-define=BASE_URL=https://api.example.com
```

**After** `dart run tool/strip_sample_features.dart --apply` (both samples removed), `tool/golden/stripped/integration_test/app_e2e_test.dart` replaces `app_e2e_test.dart` outright, so editing the copy here does not affect that variant. `--remove-tasks` and `--remove-feature-flags` keep this file as it is. <!-- strip:strip-tool line -->

## CI

The workflow fails the job when the summary reports `Total: 0` or a non-zero `Failed:` count. Both were real false-green paths: `patrol test` exits 0 on an empty test set, and piping its output without `pipefail` swallowed a genuine failure. A green run here is now meaningful.

Patrol does **not** run on every PR by default. Use **GitHub Actions → E2E Android (Patrol) → Run workflow** (see [`.github/workflows/e2e-android.yml`](../.github/workflows/e2e-android.yml)). You may need a reachable API if login hits the network.

## More context

- [Testing summary](../docs/guides/testing/testing-summary.md)
- [Repository layout](../docs/guides/onboarding/repository-layout.md)
