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
