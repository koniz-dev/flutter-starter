# Independent postmerge QA and security review — #1261

Merged main: `e2e848b51354c0beee82c4f3d984d25d9ca539fb` (PR #1271). Accepted candidate: `71c73a0f31e1ffa9d84637948c46a46015650258`. Both trees: `5e30c109f6776dc198e86027be18a3188a6a8574`.

**QA: PASS. Risk-gated security review: PASS. No new finding requires filing.** Publication and closure remain root's final steps.

## Independently executed acceptance

Command: `.git/codex-issue-work/sdk-350/flutter/bin/flutter test test/features/auth/presentation/screens/auth_http_rejection_test.dart test/core/localization/http_failure_localizations_test.dart .git/codex-issue-work/1261-review-probe_test.dart --reporter expanded`

Result: exit0, **all41 tests passed on merged main**. Raw result: `1261-postmerge-review-tests.log`. These are26 real-screen cases,8 real-Dio-to-localization cases, and7 independent neighboring-contract probes. This rerun does not merely inherit the premerge result.

Both login and registration400/409 display rejection/check-information text and429 displays wait text in en/es/vi/ar. The screen cases invoke the real repository/usecase/notifier and verify the remote datasource was called; raw backend detail is absent. The503 controls still show failureServer and explicitly show neither rejection nor rate-limited text. The original-source baseline24 failures/two passing503 controls establishes the requested counterfactual, including register409.

The real Dio mapper/localization matrix preserves status information and existing typed401/403/404/422 messages. Independent controls rerun code/status precedence in all four locales,503/null-status fallback, timeout and invalid-credentials app codes. Real repository refresh400 remains AuthFailure/REFRESH_TOKEN_EXPIRED;429/503 remain ServerFailure with their statuses. The UI wording change therefore does not reclassify refresh throttling as a dead session or alter persisted credentials.

## Evidence and process audit

- Read fresh live issue body/owner/status: open, assigned only to koniz-dev, exactly one status:in-progress; epic:i18n matches the final localization-only production change. Actual acceptance criteria were checked against the executions above.
- Read E/docs/verification/issue-1261/format.log, analyze.log, tests.log: format629 files unchanged, analyzer clean, full suite4487 passes/14 intentional skips, all exit0.
- Independently fetched all six actual current-head PR checks: five Strip variants and Quality gate all SUCCESS (`1261-postmerge-review-ci.json`).
- Accepted and merged trees are mechanically identical. No duplicate full suite was needed; focused behavior was independently rerun on merged source.
- Mechanical refs check over3edcb4c9c0a776f39bb3b8fe4a3a5ea1a11b07fd..HEAD passes; squash commit references1261 without an auto-closing keyword (`1261-postmerge-review-refs.log`).
- Read the gen-l10n idempotence artifact; premerge generated diff and independent byte comparisons confirm both new getters match the four ARB values. Existing delegate adapter headers are retained.
- No golden/PNG is cited as wording proof. This is tier1 visible-text behavior, with no device-only/UAT claim needed.

## Security scope

Reviewed the final presentation-only production diff and neighboring mapper/auth refresh behavior. Failure.message remains log/debug information and is never rendered by this localizer. Known client status takes precedence over colliding backend codes; all shown values are generated localized strings. The independently rerun focused log contains no raw backend-detail sentinel.

No auth persistence, token logging, permission, dependency, endpoint or workflow changes were added. Domain failure classes and mappers are unchanged. Refresh contracts are explicitly probed as above, and root's full-suite evidence covers existing auth/transport behavior. The two late503 negative assertions strengthen the test and assertionless-test guard without suppressing checks.

Limits: these host tests inject ServerException at the remote boundary or exercise real Dio error mapping with synthetic responses. They establish screen/localization/domain behavior, not a live backend, physical device rendering with production fonts, or external translation certification. No such assurance is required by this issue.

Reviewer `/root/review_1261` made no tracked source/test/doc edits, Git mutations, outbound comments or duplicate full-suite runs. Only scratch probes/reports under `.git/codex-issue-work` were written.
