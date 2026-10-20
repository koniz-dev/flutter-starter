# Issue 48 - `--dart-define` never resolves in AOT builds

Verified against `main` after PR #70 merged (commit `67e09a6`).

## Artifact index

| File | What it is |
|---|---|
| `aot_probe.dart` | Standalone probe comparing the two lookup forms. Reproduces the defect and the fix outside Flutter, so it can be AOT-compiled. |
| `aot_probe.log` | The probe compiled with `dart compile exe` (AOT) and run, plus a JIT run for contrast. |
| `criterion-1-release-build-ab.txt` | The real app built twice with `flutter build macos --release --dart-define=BASE_URL=...`, pre-fix and post-fix, with the release AOT snapshot searched for the supplied URL. |
| `dart_defines_test.log` | `test/core/config/dart_defines_test.dart` on a plain run: 11 pass, 1 skipped. |
| `dart_define_supplied.log` | The same file run with `--dart-define=BASE_URL=https://api.example.com`: 12 pass, the end-to-end case no longer skipped. |
| `negative_controls.log` | Both mutations that should break the suite, applied and reverted: the runtime-keyed call, and a `.env.example` key missing from the const table. |
| `criterion-4-docs.txt` | The corrected text now in `pubspec.yaml`, `README.md`, and `docs/guides/configuration.md`. |
| `criterion-5-audit_template.log` | `./scripts/dev/audit_template.sh`, exit 0. |
| `format.log`, `analyze.log`, `tests.log`, `goldens.log` | `scripts/test/run_acceptance.sh 48` gate logs. |
| `home_screen.png` | Acceptance golden. Regression check only - it shows the app still renders, and proves nothing about configuration. Ahem renders text as opaque blocks, so no wording can be read from it. |

## Criterion map

| Criterion | Artifact |
|---|---|
| 1. dart-define value returned in an AOT build | `criterion-1-release-build-ab.txt` (this app, release build, value absent before the fix and present after), `aot_probe.log` (the mechanism in isolation), `dart_define_supplied.log` (the `EnvConfig`/`AppConfig` chain end to end on the host VM). Observing the value at runtime in an installed release build is a human step - see the issue comment. |
| 2. every key covered, drift fails a test | `dart_defines_test.log` (`key coverage` group), `negative_controls.log` Control B |
| 3. host-VM test proves the const path is used | `dart_defines_test.log` (`dart-define mechanism` group), `negative_controls.log` Control A |
| 4. docs accurate about build modes and platforms | `criterion-4-docs.txt` |
| 5. `audit_template.sh` exits 0 | `criterion-5-audit_template.log` |

## What these artifacts do not show

`flutter test` runs on the JIT VM, where a non-const `String.fromEnvironment`
resolves correctly. That is why criterion 3 is asserted at the source level
(no non-literal `fromEnvironment` argument anywhere in `lib/`) rather than by
value, and why the AOT half of criterion 1 is demonstrated by inspecting
compiled binaries rather than by reading a value out of a running app.
Nothing here runs the Flutter engine in release mode on a phone, and
`AppConfig.printConfig()` is debug-only, so the effective `AppConfig.baseUrl`
of an installed release build was never printed or observed by this session.
