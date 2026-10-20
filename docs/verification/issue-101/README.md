# Verification evidence - koniz-dev/flutter-starter#101

Commit under test: `8fe402e` (PR #133, squash-merged to `main`).

## What proves what

| Artifact | What it establishes |
|---|---|
| `reachability-prefix-repro.log` | The **contrast run**. Same suite, with only `retry: _neverRetry` reverted on the startup container. 6 of 8 fail: four provider reads throw `TimeoutException after 0:00:05` having never completed, both end-to-end cases report `main() did not return within 20s`. |
| `reachability-postfix.log` | The same suite on the merged fix: 8 passed in 4 s. |
| `criterion3-grep.txt` | `grep -n "ProviderContainer(" lib/main.dart` plus the surrounding comment naming this issue. |
| `tests.log` | Full `flutter test` on merged `main`: 2645 passed, 7 skipped (golden-tagged). |
| `analyze.log`, `format.log` | `flutter analyze` clean; `dart format` check clean. |
| `goldens.log` | The golden-tagged acceptance run. |
| `goldens-checksums.txt` | Every copied PNG is byte-identical to its `test/acceptance/goldens/` original. |

## What the PNGs do NOT prove

`run_acceptance.sh` copies all 11 standing goldens in. **No criterion here rests
on any of them**, and `goldens-checksums.txt` shows all 11 are unchanged, so the
run introduced no golden regression either.

`startup_failure.png` is the trap worth naming. It is a genuine render of
`StartupFailureApp` - error icon, title, body copy, a purple Try again button -
but it comes from `test/acceptance/startup_failure_acceptance_test.dart`, which
**pumps the widget directly**. That is exactly how closed issue #60 passed its
"no blank window; a test asserts rendering" criterion while the screen remained
unreachable from `main()`. It proves the screen paints. It says nothing about
whether anything can get to it, which is the whole of #101.

Reachability is proved by the two logs above instead, because those drive the
real `app.main()` and assert on what it handed to `runApp`.

Per repository convention: `flutter test` renders text with the Ahem font, so
every glyph in these PNGs is an opaque block. Wording is asserted with
`find.text()` in the tests, never read off a screenshot.
