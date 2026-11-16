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


## Revised-head re-review — PASS

Reviewed revised head `4e38c2c8e53e71e14e11e205d212d53392ca08fe` against unchanged base, including all eight changed files and the incremental fixes. Both initial P2 defects are resolved. No additional introduced defect found in the reviewed scope. Initial report/log remain preserved in `1279-initial-independent-review.md` and `1279-initial-independent-tests.log`; the unchanged original probe file is retained.

The restore loop now rechecks pending persistence synchronously immediately before capturing the read epoch. A reservation arising while its empty wait was resolving therefore causes another wait, rather than partial-state reads. The Stopwatch carries one timeout budget across iterations, while the existing epoch checks protect reads against a reservation beginning after the synchronous check.

The interceptor now rejects an eligible API-origin 401 during pending persistence before refresh classification, without a forced logout or epoch change. Origin/auth-endpoint exclusions execute first, preserving their established error behavior. Normal fatal refresh handling outside replacement is unchanged. The committed regression tests encode both originally failing schedules; no assertion weakens the prior successful-session guarantees.

Independent reruns at the revised head:

- Original two adversarial probes, unchanged: 2/2 PASS. The remote-response/restore race now succeeds with B persisted. The pending-persistence401 is canceled while B sign-in succeeds and cold restore returns B.
- Five additional pending-persistence controls: 5/5 PASS for login/register/logout/refresh endpoints and a foreign origin. Each original401 remains a Dio badResponse, refresh is not called, generation is unchanged, and B completes and cold-restores successfully.
- Raw re-review output: `1279-independent-rereview-tests.log`. The first five-control invocation had an incorrect reviewer harness expectation against ApiClient's mapped ServerException; changing only the probe to inspect raw `client.dio.get` exposes the intended Dio error type and all five pass. This harness correction is recorded in raw output; it is not a product failure.

No full suite duplicated; root owns broader CI/host gates. No tracked edits or real network/credential activity performed.


## Documentation quote follow-up — PASS

Inspected the working diff in `docs/api/features/auth/providers.md`: it adds `sessionSink: ref.read(sessionTerminationSinkProvider)` to the quoted repository declaration and documents all three optional integration dependencies. The quote now matches the production provider declaration. The adjacent explanation matches implementation: absent httpCache loses repository logout response-cache eviction, an unshared generation loses coordinated repository/interceptor invalidation, and absent sessionSink removes the replacement path's notification that clears the previous visible user. Core's null default is deliberately degraded; the app composition root applies authModuleOverrides, whose lazy Riverpod sink clears authNotifierProvider. No production/test change is included in this follow-up.

Targeted `flutter test test/docs/auth_providers_quotes_test.dart --reporter expanded`: 11/11 PASS. Actual raw output is preserved in `1279-doc-followup-review.log`. No tracked edits made by reviewer. This doc-only correction introduces no additional review finding.

# Postmerge QA/security review — PASS

Issue1279 / PR1293. Reviewed merged main `285fd981076db8c1dddd4503d16f42ee2c9af8bd` against accepted PR head `f997c4c58d6fce1c03474233f44c3f2265675852`. `git diff --exit-code <accepted> HEAD` exited0: whole-tree parity independently confirmed. No new correctness/security defect found. Both originally identified P2 findings remain resolved.

## Fresh postmerge verification

`flutter test test/features/auth/sign_in_persistence_test.dart .git/codex-issue-work/1279-independent-probe_test.dart .git/codex-issue-work/1279-independent-controls_test.dart --reporter expanded` exited0, 44/44 PASS on main: 37 committed persistence cases, two unchanged original adversarial probes, five pending-persistence auth-endpoint/foreign-origin controls. Raw output: `1279-postmerge-review-tests.log`. All transport is fake; no live backend, credentials, platform Keychain/Keystore, or real-device behavior is claimed.

## Criterion coverage

| Criterion | Inspected proof | Outcome |
| --- | --- | --- |
| Login/register without refresh removes the previous refresh token | Postmerge raw tests: both complete-pair cases over real local datasource/SecureTokenStore; fresh repository/store identity restore | PASS |
| Persistence failure leaves no failed restorable session and cannot delete later successful sign-in | Postmerge raw tests: applied false/Exception/Error access, refresh and user failures; durable contents checked before cold restore; held writes/rollback; queued timeout; logout; reentrant listeners | PASS |
| Remote rejection/transport failure preserves existing usable session before replacement | Postmerge raw tests: both seeded-A remote-failure controls preserve user and pair and cold restore | PASS |
| Real stores and pending ordering plus required checks/review | 44 postmerge tests; initial independent failures and revised passing logs; host format/analyzer/tests logs; final-head CI snapshot and Quality tail | PASS within host scope |

The two original race probes still succeed: queued remote response cannot bypass an empty restore barrier; pending-persistence401 cancels only its API request and cannot force logout. Five additional controls preserve original Dio badResponse behavior for excluded auth endpoints/foreign origin, with no refresh or epoch change and successful B cold restore. Physical eviction still depends on successful store clears; permanent clear refusal is documented, not misrepresented as guaranteed removal.

## Evidence and gates inspected

Opened `../flutter-starter-evidence/docs/verification/issue-1279/{format,analyze,tests}.log`: format636 files/0 changed/exit0; analyzer no issues/exit0; full host4545 passed/14 intentionally skipped/exit0. No duplicate full suite run.

Opened W's `1279-quality-final-tail.log`, `1279-ci-current.json`, `1279-evidence-draft.json`, and `1279-root-inspection.md`. Quality tail records4544 CI tests passed/16 skipped, coverage96.69% above94%, and tracked-file guard clean. All seven final PR checks are successful, including five Strip variants and Docs check. REST run43869181453 independently reports completed/success at accepted head `f997c4c58d6fce1c03474233f44c3f2265675852`.

Reviewed evidence draft's one-row-per-criterion claims against actual tests/logs and prior independent findings. Claims are supported; host versus native/live-backend limitations are clear. The docs quote follow-up was independently inspected and passed11/11; no production changes followed the accepted code review. Root retains responsibility for completing evidence publication, final G2 checks, changelog/tracker/closing steps. No screenshot/golden is cited as proof of this nonvisual auth/storage mechanism.

`../flutter-starter-maintainers/scripts/check_issue_refs.sh --range HEAD^..HEAD` exited0; squash message contains `Refs koniz-dev/flutter-starter#1279` and no autoclosing keyword.

Live read-only REST issue snapshot `1279-postmerge-live.json`: state=open; exactly one status=['status:in-progress']; exactly one assignee=['koniz-dev']. Ownership matches current session owner koniz-dev. The issue remains in progress pending root's evidence/close workflow; this is expected at postmerge QA.

No tracked files edited, no outbound comments/filings, and no full-suite duplication. No introduced defect requiring a fix or separate finding was found in this postmerge pass.

