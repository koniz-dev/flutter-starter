# Independent premerge auth/storage review — PR 1293

Reviewed base `a7372ac0f3445e9a1627048d52d742c8196cbc05` to head `e8311b54d64f151786db103aef23ffa7aabebd14` against CLAUDE.md, maintainer process G1b, W/1279-live.json, actual seven-file diff, concrete AuthLocalDataSourceImpl / SecureTokenStore, default DI and AuthInterceptor consumer behavior. No tracked edits, outbound mutations, real network or credentials used. Probe file and raw test log reside under `.git/codex-issue-work/`.

## Initial verdict: changes required

### P2 — restore barrier admits a newly reserved replacement and evicts it

Location: `lib/features/auth/data/repositories/auth_repository_impl.dart:269-273`.

`persistenceSettled()` can complete while no persistence is registered, then a queued remote response starts persistence before `getCurrentUser` resumes. Because restore captures its generation *after* that await, it adopts the replacement epoch and can read old access credentials while clearCache has already removed their user. `_discardUnrestorableSession()` then legitimately considers its captured epoch current, invalidates and clears the sign-in in progress.

Deterministic probe: seed A, start B with held remote response; complete B remote response and immediately call getCurrentUser in the same synchronous turn. Hold B user write to expose the ordering; release after settling. B unexpectedly returns SESSION_TERMINATED, restore returns null, vault is empty. A read that observes a newly pending replacement must wait/retry under the same overall bound, or reject an epoch change captured before waiting rather than joining its partial state.

### P2 — the new refresh guard makes an unrelated 401 kill sign-in persistence

Location: `lib/features/auth/data/repositories/auth_repository_impl.dart:457-466`; consumer `lib/core/network/interceptors/auth_interceptor.dart:549-552`.

While a new pair has landed but its user write remains pending, the token store can certify a stable access snapshot. A protected API request returning 401 reaches `refreshToken()`, whose new guard returns UnknownFailure SESSION_TERMINATED without advancing the generation. The interceptor observes its generation still current and classifies that failure as fatal, calls forced logout, deletes the pair and invalidates the sign-in. The guard must prevent refresh of an uncommitted pair without causing its consumer to end the replacement session.

Deterministic probe uses production authModuleOverrides / apiClientProvider, real local datasource and SecureTokenStore with fake physical stores, and an HttpClientAdapter returning401 (no actual transport). Hold B user write; request `/users/me`; release user write. B unexpectedly returns SESSION_TERMINATED and vault is empty. Both probes fail at the stated PR head; raw output is in `1279-independent-tests.log`.

## Other reviewed behavior

Complete pair replacement clears omitted refresh tokens; credentials precede user writes and rollback runs after applied false/throw writes. Persistence reservation blocks subsequent sign-ins until stale user writes and rollback settle, preserving a later successful session. Remote rejection before persistence preserves existing stored and visible session. Capturing intended epoch before listener notification fixes listener reentrancy ownership. Default sink wiring is lazy and does not introduce an eager provider cycle. Restore and next-sign-in waits are bounded; logout/forced teardown can still clear credentials without waiting on a hung user write. Physical cleanup failure cannot ensure cold eviction, as explicitly documented; permanent store refusal is a storage limitation, not a new finding here. HTTP-cache invalidation on direct A-to-B sign-in is pre-existing and outside this issue, so is not reported as an introduced defect.

## Validation

Independent probes: two deterministic failures above, captured raw.
Focused submitted test files: `flutter test test/features/auth/sign_in_persistence_test.dart test/core/session/session_epoch_test.dart test/features/auth/data/repositories/auth_repository_impl_test.dart --reporter expanded` exited 0, 101 tests passed. Raw output is appended to the same log. No full suite duplicated.
