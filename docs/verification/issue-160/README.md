# Issue 160 - a healthy boot must be proven to reach `runApp` with `MyApp`

Change merged as `e9e80eb` (PR #192), on top of `ddaa43e`.

The issue: both end-to-end cases in
`test/core/startup/startup_reachability_test.dart` *expected*
`StartupFailureApp`, so a regression turning every launch into the failure
screen made them pass harder. QA proved the hole by mutation. This directory
re-runs those same two mutations against the new test.

## How the `runApp`-inside-`runAsync` obstacle was cleared

The file's own comment said a healthy end-to-end case could not be written,
because `runApp` runs inside `tester.runAsync` and building the full `MyApp`
tree from a warm-up frame there never returns. That is not what happens on the
pinned toolchain (Flutter 3.47.0, Dart 3.13.0):

- `runApp` calls `scheduleAttachRootWidget` then `scheduleWarmUpFrame`.
- `scheduleAttachRootWidget` defers `attachRootWidget` onto `Timer.run`.
- `AutomatedTestWidgetsFlutterBinding.scheduleWarmUpFrame`
  (`packages/flutter_test/lib/src/binding.dart:2352`) does a *synchronous*
  `handleBeginFrame` / `handleDrawFrame` pair.

So the warm-up frame runs before the root widget is attached and never touches
the `MyApp` tree at all. `main()` returns normally, and a single bounded
`pumpAndSettle` afterwards settles router, Riverpod scope and localization -
`test/main_test.dart` already proves that tree quiesces (the #40 regression
guard). No new seam in `lib/` was needed; nothing in `lib/` changed.

The three traps named in the issue were all avoided by reusing the setup the
file already had: `SharedPreferences.setMockInitialValues`, an in-memory
Keychain over `plugins.it_nomads.com/flutter_secure_storage`, and a `.env`
served over the `flutter/assets` channel.

## Artifacts

| File | What it is |
|---|---|
| `baseline-startup-reachability.log` | The file on merged `main`. 9 tests pass, including the new case at `+8`. |
| `mutation-a.patch` | Mutation A applied to `lib/main.dart` (`git diff`, applies cleanly to `e9e80eb`). |
| `mutation-a-startup-reachability.log` | The file under mutation A. The new test is the only failure, with its `reason` printed. |
| `mutation-a-full-suite.log` | `flutter test --timeout=5m` under mutation A: `+2691 ~8 -1`, and the single entry under `Failing tests:` is the new test. |
| `mutation-b.patch` | Mutation B applied to `lib/core/localization/localization_service.dart`. |
| `mutation-b-startup-reachability.log` | The file under mutation B. Same single failure. |
| `mutation-b-full-suite.log` | Full suite under mutation B: `+2680 ~8 -12`. QA measured 11 failures, all inside the mutated service's own unit tests; the 12th is the new test, marked `[E]` at line 1709. |
| `audit_template.log` | `./scripts/dev/audit_template.sh`, exit 0, `+2692 ~8`. |
| `format.log`, `analyze.log`, `tests.log`, `goldens.log` | `./scripts/test/run_acceptance.sh 160` on merged `main`. All exit 0; `tests.log` ends `+2715 ~8: All other tests passed!`. |
| `goldens-checksums.txt` | Proof the PNGs below are unchanged. |
| `*.png` | **Cite none of these.** `run_acceptance.sh` copies every standing golden under `test/acceptance/goldens/` into the evidence directory regardless of the issue. All 13 are byte-identical to their `test/acceptance/goldens/` counterparts (see `goldens-checksums.txt`; 8 distinct images, some goldens share bytes). None of them exercises `main()`, and the criteria here are text and widget-type assertions, which a golden could not show anyway - `flutter test` renders every glyph as an opaque Ahem block. |

### Log trimming

Every `.log` here had ANSI escapes stripped and the app logger's own box-drawn
frames removed:

```bash
perl -pe 's/\e\[[0-9;]*m//g' <raw> | grep -v '^[┌│├└]'
```

That drops only `LoggingService` output. Every test-result line, every failure
block and every summary line is intact. `format.log`, `analyze.log`,
`tests.log` and `goldens.log` were additionally head/tail excerpted by
`run_acceptance.sh` itself, which is that script's normal behaviour on a
passing gate.

## Reproducing

```bash
git apply docs/verification/issue-160/mutation-a.patch
flutter test test/core/startup/startup_reachability_test.dart --timeout=none
git checkout -- lib/main.dart
```

Same for `mutation-b.patch`. Both mutations carry `// ignore: dead_code` so
`flutter analyze` stays clean - mutation B in the original report was
analyzer-clean on purpose, and a mutation the analyzer catches would not model
the regression being guarded against.
