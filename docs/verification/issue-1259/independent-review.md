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
