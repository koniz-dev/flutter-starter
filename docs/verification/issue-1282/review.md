# Independent premerge review: issue 1282 / PR 1296

Reviewed actual base `985cc6b2506a032671f85640cc12424632c71b2a` through head `88fadddd80da674c77d6f2df3e633a13d7f62ec8`, branch `codex/fix-runtime-system-locale`. Read project CLAUDE.md, maintainer process.md and issue snapshot 1282-live.json. No implementer verdict was used. No tracked files changed and no outbound mutations performed.

## Verdict

No introduced defect found. The new observer is registered in initState and removed in dispose; both the platform handler and deferred mount refresh check mounted before accessing ref. The post-frame refresh handles a platform change between bootstrap restoration and mounting without mutating a provider during widget creation. All actual app startup restore callers (normal and stripped main) now use restoreLocale rather than marking the device fallback as a manual choice.

The notifier records a manual selection before updating state, and both asynchronous provider results and explicit startup restoration respect that selection. Stored preferences continue to win through LocalizationService.getCurrentLocale on refresh. Riverpod invalidation discards obsolete pending provider generations; an independent completer probe verified that an older future completing after its replacement does not overwrite the newer result. Current language switcher callers still set notifier.locale after their persisted selection completes, so their public API stays compatible. A root provider scope override of localeStateProvider is still honored by MyApp; mounting/unmounting with an UncontrolledProviderScope was exercised independently.

MyApp inherits ConsumerStatefulWidget instead of ConsumerWidget. Removing the old test that merely asserted ConsumerWidget inheritance removes an obsolete implementation assertion, not behavioral coverage. Retained main tests create and render the real MyApp and verify MaterialApp configuration, explicit provider overrides and directionality. No other production constructor call relies on ConsumerWidget typing.

The stripped golden main is byte-identical to lib/main.dart (`cmp` exit 0). A fresh archived head successfully applies the remove-tasks sample strip including its forbidden-reference guard. The observer/provider changes add no sample-only imports or dependencies. Apps that replace MyApp entirely must provide their own platform observer, as the provider documentation explicitly states; this is not a regression in an existing caller.

## Executed checks

All output is retained verbatim in `1282-independent-tests.log`, including unsuccessful harness attempts and their correction. SDK: supplied local Flutter 3.50 / Dart 3.14, no global SDK changes.

- Head: `flutter test test/core/localization/device_locale_test.dart test/core/localization/localization_providers_test.dart test/core/startup/startup_reachability_test.dart --plain-name 'runtime locale' --reporter expanded`: **8 passed**, exit 0.
- Actual isolated base archive with only those three head test files overlaid: same command with `--no-pub`: **2 passed, 6 failed**, exit 1. The first attempt lacked package_graph.json and ran no tests; the second attempt copied that dependency metadata and executed against the isolated base package root.
- Independent `.git/codex-issue-work/1282_independent_probe_test.dart`: **2 passed**, exit 0. Observer invalidation stops after unmount and resumes with a current-device refresh on remount. Provider completions from an invalidated generation cannot overwrite a newer result; a later manual selection survives a pending result and restoreLocale. The initial read-only provider probe expected invalidation alone to eagerly evaluate a provider; corrected it to explicitly read the refreshed provider. That harness expectation was not an app failure.
- `flutter test --no-pub test/main_test.dart test/shared/widgets/language_switcher_test.dart --reporter expanded`: **26 passed**, exit 0.
- Fresh archived head: `dart --packages=<main package config> tool/strip_sample_features.dart --apply --remove-tasks --force`: exit 0, strip complete. Force bypassed only the archive-without-git working-tree safety check; forbidden-reference scanning remained active.
- `cmp lib/main.dart tool/golden/stripped/lib/main.dart`: exit 0. `git status --short`: empty.

## Added-test discrimination

| Added case | Actual base | Head |
|---|---|---|
| fallback captured before mounting | fails: en instead of vi | pass |
| platform changes with no preference | fails: en instead of vi | pass |
| platform changes with corrupt preference | fails: en instead of vi | pass |
| stored choice survives platform change | pass (control) | pass |
| in-memory choice survives platform change | pass (control) | pass |
| delayed provider restore preserves new manual choice | fails: en replaces es | pass |
| change as real bootstrap finishes | fails: en instead of vi | pass |
| platform change after real startup | fails: en instead of vi | pass |

Host tests verify framework-delivered locale events; no claim is made about physical-device settings UI, Patrol, full suite or CI. Root session owns the full host/CI gates and publication.

# Independent postmerge QA: issue 1282 / PR 1296

PASS: no introduced defect identified. Reviewed merged main `d1b5830f4b73ac8abe118b6eba5c25c1d826d5f4` and independently confirmed zero diff against accepted head `88fadddd80da674c77d6f2df3e633a13d7f62ec8`. GitHub read confirms PR 1296 merged to that commit with that accepted head. No tracked edits or outbound mutations were made.

## Postmerge executions

Actual untrimmed output is in `1282-postmerge-review-tests.log`. Using the supplied local Flutter 3.50 SDK:

`flutter test --no-pub test/core/localization/device_locale_test.dart test/core/localization/localization_providers_test.dart test/core/startup/startup_reachability_test.dart .git/codex-issue-work/1282_independent_probe_test.dart --name 'runtime locale|independent' --reporter expanded`

**10 passed, exit 0**: all eight submitted runtime locale cases plus both independent observer-lifetime/async-race probes. The first invocation used --plain-name with the regex text and selected zero tests (exit 79); the corrected --name invocation executed all ten. The raw log preserves both. No duplicate full suite was run.

The focused cases verify absent/corrupt preferences follow changing platform locales, unsupported devices fall back correctly, translations and directionality change, stored and manual choices remain authoritative, stale asynchronous restoration respects a manual pick, and real-bootstrap/pre-mount timing windows refresh. Independent probes verify no observer reads after unmount, current-device refresh after remount, obsolete invalidated futures cannot overwrite their replacement, and manual picks survive later pending data and startup restoration.

`cmp lib/main.dart tool/golden/stripped/lib/main.dart` exits 0. `git diff --exit-code <accepted> <merged>` exits 0. `check_issue_refs.sh --range 985cc6b2506a032671f85640cc12424632c71b2a..HEAD` passes, verifying the squash message references issue 1282 with Refs and contains no auto-closing keyword. Main tracked status remains clean.

## Inspected evidence and gates

- Evidence `docs/verification/issue-1282/format.log`: 638 files, zero changed, exit 0.
- Evidence `analyze.log`: no issues found, exit 0.
- Evidence `tests.log`: host suite 4569 passed / 14 skipped, exit 0.
- Work file `1282-quality-final-tail.log`: CI 4568 passed / 16 skipped, 96.71% coverage above 94% floor; final tracked-file check explicitly says No tracked file changed.
- Work file `1282-ci-current.json` and independent live PR check read: Quality plus all five Strip variants SUCCESS on accepted head 88fadddd. Parity makes these results applicable to the merged source tree; this is not a claim of a new postmerge CI run.
- Read `1282-evidence-draft.json`, `1282-root-inspection.md`, source diff and premerge independent report/log. Draft correctly distinguishes six red-on-actual-base regressions from two passing choice controls and describes host framework events rather than physical-device settings UI. Baseline metadata and read-only probe harness corrections are disclosed. No screenshots are present or needed for these behavioral criteria.
- Live issue 1282 is still OPEN, assigned to koniz-dev, with status:in-progress and epic:i18n, ready for the root session to publish evidence and close after its remaining G2 checks. Closing/publishing was not performed by this reviewer.

The removed MyApp test only asserted obsolete ConsumerWidget inheritance. Existing mounted MaterialApp and provider-override behavioral checks remain, and 26 main/picker tests were independently green before merge; the accepted and merged source trees are identical. Observer add/remove, mounted ref guard, deferred initial refresh, explicit/manual precedence and production/stripped bootstrap parity remain correct on the merged tree.

## Scope and remaining ownership

This independent QA confirms the requested postmerge mechanism tests and inspects existing full host/CI evidence. Root owns its separate G2 audit, evidence commit/push, changelog and issue closure. Physical-device settings UI and Patrol remain outside this host verification. No new issue or fix is required by this review.

