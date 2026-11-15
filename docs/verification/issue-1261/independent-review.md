# Independent premerge review — issue #1261 / PR #1271

Reviewer: fresh read-only subagent `/root/review_1261`. PR: https://github.com/koniz-dev/flutter-starter/pull/1271

Reviewed HEAD: `71c73a0f31e1ffa9d84637948c46a46015650258`. Tree: `5e30c109f6776dc198e86027be18a3188a6a8574`. Base: `3edcb4c9c0a776f39bb3b8fe4a3a5ea1a11b07fd`.

**Verdict: PASS. No unresolved blocking finding in the reviewed diff.** Root owns full host/current-head CI completion and the merge gate.

## Source and acceptance review

Read the live issue body/status and inspected the complete localization change, ARBs/generated getters, existing inventory assertion, real Dio-to-Failure matrix and real LoginScreen/RegisterScreen tests. The issue is open, assigned only to koniz-dev, with exactly one status label (status:in-progress).

The production change is presentation-only: a ServerFailure carrying429 selects the wait message; other unclassified HTTP4xx select request rejection before backend code lookup. ExceptionToFailureMapper, Failure types and auth/retry classification are unchanged. Typed401/403/404/422 retain their existing messages. Server failures without a client status retain the existing subtype/code fallbacks. The normal5xx path still selects failureServer. Raw backend failure text is never returned.

This preserves an important neighboring auth contract: a rejected refresh400 remains AuthFailure/REFRESH_TOKEN_EXPIRED, while refresh429/503 remain ServerFailure, so adding localized wording does not inadvertently turn throttling into forced logout. Existing app-owned timeout/invalid-credential codes and null-status server fallback remain intact.

The committed screen tests use real repository/usecase/notifier/screens with a remote datasource throwing ServerException, rather than mocking rendered Failure output. They verify remote invocation, translated visible text and absence of raw backend detail. Their24-case matrix covers400/409/429 across login/register and en/es/vi/ar, with two503 controls. I inspected the actual baseline log showing24 failures and two passing503 controls. The translation inventory assertion changes13 to15 while retaining checks for every failure key in all four locale ARBs.

Inspected generated diffs: the new abstract getters and four locale implementations correspond to the two added ARB keys; existing localization delegate adapters remain unchanged. Independently matched both generated string values byte-for-byte to each of the en/es/vi/ar ARBs. No dependency, platform, route, auth-persistence or workflow change is included.

## Independent executed probes

Command: `.git/codex-issue-work/sdk-350/flutter/bin/flutter test .git/codex-issue-work/1261-review-probe_test.dart --reporter expanded`

Final result: exit0, all **7 tests passed**. Source: `1261-review-probe_test.dart`; raw result: `1261-review-probe.log`.

- Four locale controls independently check409 and429 authoritative-status precedence over colliding backend codes,503/null-status server fallback, existing timeout app code and typed invalid credentials.
- Real repository refresh400 retains AuthFailure and REFRESH_TOKEN_EXPIRED; localized session-ended text remains unchanged.
- Real repository refresh429 retains ServerFailure/status429 and now renders the wait message.
- Real repository refresh503 retains ServerFailure/status503 and server text.
- Repository controls verify no local teardown is called by these failed refresh operations.

The scratch probe initially needed the public Result extension import; the corrected final run above is the executed seven-pass result. No tracked source/test/doc edits, Git mutations, outbound comments or duplicate full-suite run were performed. An initially observed test-description line-length lint was corrected by root; root targeted audit subsequently reports355 passing tests and clean analyzer. Full host and CI claims remain root-owned.

## Final fixture follow-up

Inspected the sole delta from original reviewed2c5754dbac6 to final71c73a0f31e: the existing503 widget control now directly asserts that neither request-rejection nor rate-limit text is present. This both strengthens503 classification coverage and gives the assertionless-test guard visible assertions in the test body. It does not suppress the guard or weaken helper assertions. Production and ARB/generated localization source are unchanged, so the seven independent probe results still apply. Inspected `1261-guard-and-widget.log`: all31 guard/widget tests pass (exit0). PASS retained on the final HEAD/tree above; no additional full-suite/probe duplication or tracked changes by this reviewer.
