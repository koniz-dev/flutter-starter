# Independent postmerge QA and security review — #1259

Merged commit: `6d4537f3e85a915c3d1c9d036d62fbcc6eae3cf4` (PR #1269). Accepted candidate: `36babffc54ea6632b4e399fc606f27bb97fc8853`. Both trees: `b518778eddb0ccbfb4c698f677b491948722c01c`.

**QA: PASS. Security review of this change: PASS. No new finding requires filing.** Evidence publication and issue close remain the root session's final steps; at review time the issue is correctly still open/in progress.

## Independently executed acceptance

Command: `/Users/nguyenanhkiet/Playground/flutter-starter/.git/codex-issue-work/sdk-350/flutter/bin/flutter test test/features/auth/orphaned_session_test.dart .git/codex-issue-work/1259-review-probe_test.dart --reporter expanded`

Exit 0, all **11 tests passed**. Raw output: `1259-postmerge-review-tests.log`; independent extra probe source: `1259-review-probe_test.dart`.

The five committed real-provider cases cover missing user, malformed JSON, wrong user field type, wrong preference type, and valid user control. Each orphan case starts with both credentials in real SecureTokenStore over a fake backing service, restores through the real notifier/repository/datasource chain, observes both credentials removed, then sends a real intercepted request through a fake 401 transport. It observes exactly one unauthenticated request and zero real-refresher callback invocations. Valid cached user control retains both tokens and restores the user. The original four-state baseline run was also inspected before merge and failed on retained access credentials.

The six independent probes cover null/empty/nonempty certified token refresh gates, late refresh persistence after eviction, stale cached-user Error after a newer sign-in, and stale successful read after logout. All were rerun on merged main, not merely inherited from the premerge result.

## Evidence and process audit

- Read live issue #1259 body and verified both actual acceptance criteria above.
- Live issue snapshot `1259-postmerge-issue.json`: open, assigned only to koniz-dev, exactly one status label (`status:in-progress`). No needs-UAT routing.
- Mechanical refs check over `a78bdd605eacd2e7f757c647fbc47b0cbc8d251c..6d4537f3e85a915c3d1c9d036d62fbcc6eae3cf4` passes. Squash commit carries `Refs koniz-dev/flutter-starter#1259` and no auto-closing keyword.
- Inspected E/docs/verification/issue-1259/format.log, analyze.log, tests.log directly: all exit 0; format checks 626 files with no changes; analyzer reports no issues; full suite ends with 4430 successes and 14 intentional skips. Logs are captured artifacts pending final evidence commit/publication, not merely a PASS claim.
- Independently fetched all six actual PR checks using the current-head bridge: all SUCCESS, including Quality gate and the five Strip jobs. Raw snapshot: `1259-postmerge-review-ci.json`.
- Accepted and merged source trees are mechanically identical. A duplicate full suite is unnecessary; focused behavior was independently rerun as above.
- This is nonvisual storage/network behavior. No PNG/golden is cited as evidence and no device-only step blocks the local mechanism's verification.

## Risk-gated security checks

Reviewed the two changed production files and surrounding token-store, local clear, session-generation, refresh, and logging paths. Token values continue through ITokenStore/SecureTokenStore; no new persistence of credentials in preferences. The change adds no credentials, dependencies, endpoint, permission, log statement or remote revocation call. The orphan cleanup removes local user and both tokens, advances generation before awaits, tracks teardown before invalidation, and attempts HTTP-cache removal independently. Old-generation refresh persistence is rejected, newer sign-ins wait for tracked cleanup, and stale restore cannot clear newer credentials. The empty-vault 401 guard avoids refresh/replay while preserving the nonempty control.

Checked the three currently staged evidence log contents and the new focused log for synthetic credential sentinel leakage: no `orphan-access`, `orphan-refresh` or `rotated-refresh` values appear. Request logs for the signed-out request contain no Authorization header. Existing logging interceptor sanitizes headers; this change does not weaken it. All fixture credentials in source are explicitly synthetic.

Limits: host tests use an in-memory backing service and fake transport. They do not prove physical Keychain/Keystore deletion on a real device, uninstall/reinstall OS behavior, plugin failures, or server-side token revocation. No such claim is needed for the issue's reproduced local restore/request behavior. A physical deletion failure is surfaced as ResultFailure; it cannot be promised to remove storage despite the platform refusing it.

Reviewer `/root/review_1259` made no tracked source changes, Git mutations, outbound comments, or duplicate full-suite run.
