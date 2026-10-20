# Issue 161 - acceptance evidence

Issue: koniz-dev/flutter-starter#161 - "docs: Riverpod auto-retry is disabled
process-wide, but is named and commented as if it were startup-only".

Change under verification: commit `22ebb26`
("docs(architecture): document the process-wide Riverpod retry opt-out",
PR #218), merged to `main`. This directory is the verification of that merged
state; no source change was made for it beyond the temporary, reverted probe
described below.

Verified at `main` = `22ebb26`, on macOS (darwin 24.6.0), Flutter stable,
riverpod 3.0.3.

## Result

| # | Criterion | Verdict | Artifact |
| --- | --- | --- | --- |
| 1 | Doc page states the policy, why, what still retries, what to do instead; reachable from `docs/README.md` | PASS | [`criterion1-claims.log`](criterion1-claims.log) plus the page itself, [`docs/architecture/riverpod-retry-policy.md`](../../architecture/riverpod-retry-policy.md) |
| 2 | `grep -rn "auto-retry\|defaultRetry" docs/` matches outside `docs/verification/` | PASS | [`criterion2-grep.log`](criterion2-grep.log) - 11 matches in 5 files |
| 3 | Rename away from startup-only scope, or a dartdoc first paragraph saying the policy is app-lifetime | PASS (both branches) | [`criterion3-rename.log`](criterion3-rename.log), [`criterion3-coupling.log`](criterion3-coupling.log), [`criterion3-negative-probe.log`](criterion3-negative-probe.log) |
| 4 | `tool/golden/stripped/lib/main.dart` still matches `lib/main.dart`, strip smoke stays green | PASS | [`criterion4-strip-golden.log`](criterion4-strip-golden.log) |
| 5 | `./scripts/dev/audit_template.sh` exits 0 | PASS | [`criterion5-audit-template.log`](criterion5-audit-template.log) |

Supporting runs from `./scripts/test/run_acceptance.sh 161 --no-goldens`:
[`format.log`](format.log), [`analyze.log`](analyze.log),
[`tests.log`](tests.log). Docs tooling: [`check-docs.log`](check-docs.log).

No PNG is attached and none would help. Every criterion here is about prose,
an identifier, and exit codes; `flutter test` renders text with the Ahem font,
so a golden could not show a word of the new page. The golden layer was skipped
deliberately with `--no-goldens`.

## Criterion 1, in detail

The page is `docs/architecture/riverpod-retry-policy.md`. Its section headings
answer, in order, the four things the criterion asks for:

- *what the policy is* - "The policy in one table", plus the opening sentence
  "Riverpod's automatic retry is turned off for the whole app, for the whole
  process lifetime".
- *where it is set* - "Where it is set" quotes `createAppContainer` and states
  that the same container is handed to `runApp` inside
  `UncontrolledProviderScope`.
- *why* - "Why auto-retry is off" gives the `container.read(p.future)`
  argument (an awaited-but-unlistened provider is invalidated by the retry and
  never rebuilt, so the future never completes), and "Why it could not be
  limited to startup" explains that a container-level `Retry` is never told
  which provider failed.
- *what still retries* - "What still retries": `RetryInterceptor`, Dio traffic
  only, with the boundary spelled out.
- *what to do instead* - "What to do when a provider needs retry": per-provider
  `retry:` for both hand-written and `@riverpod` providers, the two checks
  before reaching for it, and the `Result`/`ref.invalidate` alternatives.

Reachability: linked from `docs/README.md` (top "Start here" list),
`docs/architecture/README.md`, `docs/architecture/design-decisions.md`
(state-management section), `docs/guides/features/common-tasks.md` (provider
best practices) and `docs/api/core/network.md` (the `RetryInterceptor`
reference). The last two are the paths an adopter is actually on when they add
their first `AsyncNotifier` or network-backed `FutureProvider`, which is the
discovery question the issue was filed about.

The load-bearing technical claims on the page were checked against the pinned
package sources rather than taken on trust, and all hold - see
[`criterion1-claims.log`](criterion1-claims.log):

- `origin.retry ?? container.retry ?? ProviderContainer.defaultRetry` is
  verbatim `riverpod-3.0.3/lib/src/core/element.dart:685`, so the page's
  "set `retry:` on the provider and it wins over the container" instruction is
  correct.
- `ProviderContainer.defaultRetry` really is 10 attempts, 200 ms doubling to a
  6400 ms ceiling, skipping `Error` and `ProviderException`
  (`provider_container.dart:825`), which is what the page says.
- `FutureProvider` accepts `retry:` (`future_provider.dart:108`) and
  `@Riverpod(retry: ...)` exists
  (`riverpod_annotation-3.0.3/lib/src/riverpod_annotation.dart:49`), so both
  code samples on the page target real API.
- `RetryInterceptor` is added unconditionally at
  `lib/core/network/api_client.dart:128`, so "it still retries, for Dio only" is
  accurate.

## Criterion 3, in detail

The merged change took the rename branch *and* rewrote the dartdoc, so both
halves of the "either/or" are satisfied. `createAppContainer` is the name in
`lib/main.dart`, `tool/golden/stripped/lib/main.dart`,
`test/core/di/providers_test.dart` and
`test/core/startup/startup_reachability_test.dart`. The old name survives in
exactly one place, `docs/verification/issue-101/criterion3-grep.txt`, which is a
frozen evidence log quoting the code as it stood then - not a call site, and
deliberately not corrected. This evidence directory spells the old identifier
with a character class so it does not add a second false hit to future greps
(the hazard reported in koniz-dev/flutter-starter#182).

The renaming risk worth checking was not the spelling but the coupling:
koniz-dev/flutter-starter#160 wired the reachability suite to the exact factory
`main()` calls, and a rename moves both sides at once, which could silently
leave the test driving something other than production. Two runs:

- [`criterion3-coupling.log`](criterion3-coupling.log) - the untouched tree:
  48 tests pass across `startup_reachability_test.dart` and
  `providers_test.dart`.
- [`criterion3-negative-probe.log`](criterion3-negative-probe.log) - with
  `retry: _neverRetry` temporarily removed from the production factory, 6 of
  the 9 reachability tests fail with `TimeoutException ... Future not
  completed`. The coupling still bites. The edit was reverted inside the same
  script; the log ends with a clean `git status` for `lib/main.dart`.

## Reproducing

All logs in this directory were produced by the commands quoted at the top of
each file. The two multi-step ones were driven by these scripts (kept here as
text rather than as files, since a `.dart` or stray script under
`docs/verification/` is its own problem - koniz-dev/flutter-starter#187):

Coupling run:

```bash
flutter test test/core/startup/startup_reachability_test.dart \
  test/core/di/providers_test.dart --reporter compact
```

Negative probe (mutate, run, revert):

```bash
cp lib/main.dart /tmp/main.dart.bak
perl -0pi -e \
  's/ProviderContainer\(retry: _neverRetry, overrides: overrides\)/ProviderContainer(overrides: overrides)/' \
  lib/main.dart
flutter test test/core/startup/startup_reachability_test.dart \
  --timeout=45s --reporter expanded
cp /tmp/main.dart.bak lib/main.dart
git status --porcelain -- lib/main.dart   # must print nothing
```

## What this evidence does not cover

- Whether a human adopter subjectively finds the page. The five inbound links
  are verified mechanically; whether someone reads them is not something this
  harness can assert.
- Real-device or release-mode retry behaviour. The policy is a pure Dart
  configuration and is exercised by the reachability suite on the host VM only.
- The strip variants were verified locally by byte-comparing the golden
  `main.dart` against `lib/main.dart`; the three full strip-and-test variants
  are the CI jobs quoted in
  [`criterion4-strip-golden.log`](criterion4-strip-golden.log), not a local run.
