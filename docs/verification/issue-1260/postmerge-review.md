# Independent postmerge QA and security review — #1260

Merged main: `3edcb4c9c0a776f39bb3b8fe4a3a5ea1a11b07fd` (PR #1270). Accepted candidate: `af8a945952a49730f6d17ecfdf860eb9a2a2f074`. Both source trees: `0a9e06eeddab5548891ccf5be5252fad0813c3b7`.

**QA: PASS. Risk-gated security review of this change: PASS. No new finding requires filing.** Evidence publication and issue closure remain the root session's final steps.

## Independently executed acceptance

Command: `/Users/nguyenanhkiet/Playground/flutter-starter/.git/codex-issue-work/sdk-350/flutter/bin/flutter test test/core/network/cache_header_isolation_test.dart .git/codex-issue-work/1260-review-probe_test.dart --reporter expanded`

Exit 0, **all 31 tests passed** on merged main. Raw result: `1260-postmerge-review-tests.log`. This reruns the 23 committed real-ApiClient cases and all eight independent real-Dio probes; it does not merely inherit the premerge result.

- Sensitive-header acceptance: the committed cases cover the complete explicit logging roster plus a custom normalized credential name. Each pair gets two distinct transport bodies, two network calls and no persisted cache data. A preexisting anonymous cached body cannot be read or overwritten by a credential-header request. Independent probes additionally exercise mixed-case, underscore-normalized and custom secret-header shapes.
- Vary acceptance: ordinary field names, wildcard, comma-separated and multiple lines prevent storage. A Vary response evicts the prior URL entry. The independent multi-line wildcard control also passes.
- Anonymous behavior: anonymous requests without Vary still reuse their public response. Existing cache-hit/stale/error fixtures retain their assertions and now carry the current index/policy metadata.
- Migration safety: indexed previous-policy entries are purged; unindexed old bodies are not replayed with either an empty index or an indexed sibling. Refused purge keeps cache use disabled and retries later. A refused replacement write cannot stamp/index a legacy private body as current. These include independently reproduced premerge failures that are now passing.

I read the live issue's actual three acceptance criteria and inspected the class comment and docs/api/core/network.md. Both describe the shared header rule and URL-only Vary policy. Application-specific credential names outside that rule require explicit cache bypass. Physical cleanup claims correctly distinguish indexed purge from historical unindexed preference data that cannot be enumerated through this contract.

## Evidence and process audit

- Read E/docs/verification/issue-1260/format.log, analyze.log and tests.log directly: all exit 0. Format checked 627 files with no changes; analyzer found no issues; full suite ends with 4453 passes and 14 intentional skips. These are captured artifacts pending final evidence publication, not just a PASS assertion.
- Independently fetched seven actual PR checks: Quality gate, five Strip variants and Docs check all SUCCESS. Raw snapshot: `1260-postmerge-review-ci.json`.
- Mechanically checked accepted/merged tree parity. No duplicate full suite was needed; the acceptance behavior was independently rerun on merged source.
- Mechanical refs check over `6d4537f3e85a915c3d1c9d036d62fbcc6eae3cf4..3edcb4c9c0a776f39bb3b8fe4a3a5ea1a11b07fd` passes. The squash commit carries Refs #1260 and no auto-closing keyword.
- Live issue snapshot `1260-postmerge-review-issue.json`: still open, assigned only to koniz-dev, exactly one status label (`status:in-progress`). No needs-UAT routing.
- Behavior is nonvisual cache/storage/request behavior. No PNG or standing golden is used as proof.

## Risk-gated security assessment

Reviewed the changed production code and surrounding read/write/purge/credential/logging paths on merged main. The logger and cache share one header predicate; the logger's trim/case/normalization behavior is preserved. Session-token presence remains an independent cache bypass, so the interceptor registration order cannot expose a credentialed request through the anonymous cache.

Version 3 and its fingerprint include the sensitive-header roster and stricter admission policy. Failed migration operations return false and prevent both cache reads and writes until retry succeeds. Reads require current policy and index membership, so a global stamp advance cannot certify an unindexed historical body. Successful body and timestamp writes now precede index admission; a storage false result cannot bless a retained private payload.

No credential, dependency, environment asset, platform permission or endpoint was added. No new log statement prints request headers or response bodies. The final focused output contains none of the fixed synthetic credential/private-body values (`user-A`, `user-B`, `previous-private-session`, `old-user`); before-failure logs intentionally show synthetic fixture payloads to prove the regression, not real account data. The new public predicate reuses the existing redaction policy rather than weakening it.

Limits: these are host tests with fake transport and in-memory backing storage. They do not prove physical device backup cleanup or server correctness. Historical unindexed preference bodies may remain until refetch/overwrite or app-data clear; they are not reused. Unknown application-specific credential headers remain the adopter's responsibility to add to the shared rule or bypass cache explicitly, as documented.

Reviewer `/root/review_1260` made no tracked source/test/doc edits, Git mutations, outbound comments or duplicate full-suite runs. Only scratch probe/report files under `.git/codex-issue-work` were written.
