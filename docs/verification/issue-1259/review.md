# Independent premerge review — issue #1259 / PR #1269

Reviewer: fresh subagent `/root/review_1259`, read-only tracked checkout. PR: https://github.com/koniz-dev/flutter-starter/pull/1269

Final reviewed HEAD: `36babffc54ea6632b4e399fc606f27bb97fc8853`. Tree: `b518778eddb0ccbfb4c698f677b491948722c01c`. Base: `a78bdd605eacd2e7f757c647fbc47b0cbc8d251c`.

**Verdict: PASS; no unresolved blocking finding in the final diff.** This is source/targeted security review, not an assertion that independent full host or CI gates have completed. Root owns those merge gates.

## Findings and resolution

1. **No-refresh assertion needed an invocation count.** Default provider wiring can use DemoAuthRemoteDataSource without BASE_URL, so checking transport paths alone cannot establish that no refresher ran. Root added a wrapper around the real repository refresher, preserving the two other production auth ports. The final test asserts zero callback invocations as well as one unauthenticated wire request and no refresh endpoint request.
2. **The strengthened test exposed a behavioral gap.** Before the follow-up guard, the four orphan states retained zero credentials and sent no Authorization, but the 401 invoked the refresher once (expected zero). AuthInterceptor._handle401Error checked the snapshot object, not `snapshot.token`. A certified cleared snapshot is non-null by contract. Fixed on the same branch with a null/empty access-token check before calling the refresher. The finally block still resets/drains pending work, so signed-out requests complete without refresh/replay.
3. **Existing refresh test fixtures now represent an authenticated session.** Successful-refresh unit cases seed an actual access token. Missing/empty cases explicitly verify no refresher/replay. The queue error-recovery test seeds a new credentialed session after its first failed refresh performs logout, so the second request continues proving the refresh guard resets rather than accidentally testing the signed-out fast path. These changes preserve the tests' intended behaviors. A final test-only follow-up also seeds `expired-access-token` in the shared integration refresh-flow fixture, replacing its originally empty vault while retaining both expected refresher assertions and successful replay/deletion checks. I inspected the complete delta from `a5512ef8504` to final HEAD: this map initialization is the sole change; production source is identical.

## Source reasoning

The repository's orphan eviction registers a teardown before invalidating, prevents earlier refresh persistence, waits for independent local and HTTP cache removals, maps generated JSON Error values, preserves valid cached users, and checks the generation after async reads. A stale orphan read never clears a newer sign-in. Missing access-token restore behavior is unchanged. Cleanup failures are surfaced as ResultFailure; no claim is made that failed platform deletion can remove physical storage.

The new interceptor guard only rejects a 401 whose certified current access token is absent/empty. Nonempty access-token refresh follows the existing generation/revision selection path. An anonymous 401 does not create a session, and neither refresh nor replay runs. Other-origin and excluded authentication endpoints retain their existing routing.

## Independent runtime probes

Command: `/Users/nguyenanhkiet/Playground/flutter-starter/.git/codex-issue-work/sdk-350/flutter/bin/flutter test .git/codex-issue-work/1259-review-probe_test.dart --reporter expanded`

Result: exit 0, **all 6 tests passed**. Probe source and raw result are in `.git/codex-issue-work/1259-review-probe_test.dart` and `1259-review-probe.log`.

- Missing certified access state: real Dio 401 completes with no refresher invocation.
- Empty certified access state: real Dio 401 completes with no refresher invocation.
- Nonempty certified access state control: the same real Dio 401 invokes the refresher exactly once.
- A refresh started before orphan eviction cannot persist its late access or refresh response.
- A delayed cached-user Error cannot erase a successfully persisted newer login's credentials or user.
- A delayed successful cached-user read cannot return an authenticated user after logout.

I additionally inspected `1259-integration.log` on final HEAD: all 3 integration refresh-flow tests passed, including refresh/replay, excluded endpoints and failed-refresh deletion.

I also inspected root's final `1259-audit.log`: final targeted audit contains `All tests passed!` with 130 successes. `git diff --check` on the complete base-to-head range exits 0. The earlier four-failure `1259-real-state.log` is the actual reproduction of finding 2, not the final result; final validation is in the audit log.

No tracked files or Git state changed by reviewer. No duplicate full-suite run. An initial scratch-probe compilation required adding the public Result extension import; the corrected run above is the executed probe result. Real Keychain behavior and remote-server revocation are outside these host probes; the issue's local eviction/request behavior is exercised without those services.


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

