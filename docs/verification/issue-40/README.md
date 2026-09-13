# Issue #40 - acceptance evidence

`fix(performance): the widget tree never reaches an idle frame, so pumpAndSettle
times out`

Change merged as PR #44 (`eaf8a5c` on `main`).

The issue title states a conclusion that turned out to be **false**. The widget
tree does reach an idle frame. What never reaches one is the *live test binding*,
and it would fail to do so for any app at all.

## Criteria

| # | Criterion | Artifact | Result |
|---|---|---|---|
| 1 | The cause is named concretely - file and line, not a hypothesis | [`criterion-1-cause-in-source.txt`](criterion-1-cause-in-source.txt), [`criterion-1-app-not-at-fault.txt`](criterion-1-app-not-at-fault.txt), [`criterion-1-ondevice-probe-run-34740075658.txt`](criterion-1-ondevice-probe-run-34740075658.txt) | PASS |
| 2 | Scheduling removed, or documented as intentional with reason and cost | `integration_test/README.md`, `test/helpers/pump_app.dart`, `integration_test/*_test.dart` (all in `eaf8a5c`) | PASS - documented |
| 3 | A widget test pumps the full app and settles, or `pump_app.dart` documents the restriction | [`criterion-3-full-app-settles.log`](criterion-3-full-app-settles.log) | PASS - both done |
| 4 | If the cause is removed, E2E may return to `pumpAndSettle` with a dispatched run proving it | - | N/A - cause not removed, #33 not reverted |
| 5 | `./scripts/dev/audit_template.sh` exits 0 | [`criterion-5-audit_template.log`](criterion-5-audit_template.log) | PASS - exit 0, 2233 tests |

## Criterion 1 - the cause

`pumpAndSettle` is a loop that exits only on a frame where nothing further is
scheduled (`flutter_test/lib/src/widget_tester.dart:715-721`):

```dart
do {
  if (binding.clock.now().isAfter(endTime)) {
    throw FlutterError('pumpAndSettle timed out');
  }
  await binding.pump(duration, phase);
  count += 1;
} while (binding.hasScheduledFrame);
```

Patrol's binding is a live binding - `class PatrolBinding extends
LiveTestWidgetsFlutterBinding` (`patrol-3.20.0/lib/src/binding.dart:43`) - and
`LiveTestWidgetsFlutterBinding.handleDrawFrame` ends like this
(`flutter_test/lib/src/binding.dart:2817-2825`):

```dart
if (_expectingFrame) {
  // set during pump
  ...
  _expectingFrame = false;
} else if (framePolicy != LiveTestWidgetsFlutterBindingFramePolicy.benchmark) {
  platformDispatcher.scheduleFrame();
}
```

**Line 2823-2824 is the answer to the criterion.** The `else` branch runs for
every frame the test did not itself pump. On a real device vsync delivers those
continuously, so each one schedules the next. A frame is therefore always
pending, `hasScheduledFrame` is never false, the loop never exits, and it throws
`pumpAndSettle timed out` - whatever the app is doing.

Changing the frame policy does not help. The re-arming branch excludes exactly
one policy, `benchmark`, and `pumpAndSettle` refuses to run under that one
(`widget_tester.dart:699-711`):

> When using LiveTestWidgetsFlutterBindingFramePolicy.benchmark,
> hasScheduledFrame is never set to true. This means that pumpAndSettle() cannot
> be used, because it has no way to know if the application has stopped
> registering new frames.

So either frames are always scheduled, or they are never scheduled. There is no
policy under which `pumpAndSettle` works on a device.

### The app is not involved

- No frame callback, `SchedulerBinding`, `Ticker`, `vsync` or
  `AnimationController` anywhere in `lib/`. The only `Timer` is the one-shot in
  `core/utils/debouncer.dart:38`.
- `lib/core/performance/performance_screen_mixin.dart`, one of the issue's
  listed suspects, only hooks `initState`/`dispose` and is no-op by default.
- The full app settles fine under the standard binding - see criterion 3.

### On the on-device probe

The probe branch's experiment was dispatched and ran
([run 34740075658](https://github.com/koniz-dev/flutter-starter/actions/runs/34740075658)),
but its result is **corroborating, not decisive**, and its original decision rule
was wrong. Details in
[`criterion-1-ondevice-probe-run-34740075658.txt`](criterion-1-ondevice-probe-run-34740075658.txt).
Short version: the rule assumed `onlyPumps` would settle, but `onlyPumps` re-arms
frames exactly as `fadePointers` does, so "both time out" is what a binding cause
predicts - not evidence of an app cause. The probe's `print` verdicts went to
logcat and were not captured; the two tests' near-identical ~1m50s durations
against a 25s settle timeout are consistent with both timing out.

The conclusive evidence is the source, which is quoted above and does not depend
on a device being available.

## Criterion 2 - documented, not removed

The scheduling is in `flutter_test`, is deliberate for live bindings, and is not
this repository's to remove. It is documented instead, in three places that a
reader would actually hit: `integration_test/README.md` (a section saying never
use `pumpAndSettle` here, with the mechanism), `test/helpers/pump_app.dart`, and
the `_boot` doc comment in the E2E tests and their `tool/golden/` counterparts.

**Cost:** device tests must poll (`waitUntilVisible`) rather than wait for
quiescence. There is no cost to the shipped app - the re-arming loop exists only
under a test binding and never in a release build. The issue's worry about
"battery and jank on a real device" does not apply, because nothing in the app
schedules those frames.

## Criterion 3 - both branches

`test/main_test.dart` gains a regression test that pumps the whole `MyApp` -
router, Riverpod scope, localization, initial route - calls `pumpAndSettle`, and
asserts `hasScheduledFrame` is false afterwards. It passes, which is the direct
refutation of the issue's premise. It is also a control: if anything in `lib/`
ever does start scheduling frames forever, this test starts failing.

`test/helpers/pump_app.dart` gains the doc comment, including the fact - easy to
miss - that it wraps a single widget in its own `MaterialApp` and never boots the
real app.

## Criterion 4 - deliberately N/A

The cause is not removed, so the E2E tests keep `waitUntilVisible` and #33 stays.
Reverting it would reintroduce the timeout.

## Criterion 5

`./scripts/dev/audit_template.sh` exits 0 on merged `main`, 2233 tests. The
`tool/golden/` counterparts were updated with the source files; applying
`tool/strip_sample_features.dart --apply` in a clean clone gives a clean
`flutter analyze` and 1770 passing tests, the new regression test among them.
