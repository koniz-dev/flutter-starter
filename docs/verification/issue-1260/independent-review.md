# Independent premerge review — issue #1260 / PR #1270

Reviewer: fresh read-only subagent `/root/review_1260`. PR: https://github.com/koniz-dev/flutter-starter/pull/1270

Final reviewed HEAD: `af8a945952a49730f6d17ecfdf860eb9a2a2f074`. Tree: `0a9e06eeddab5548891ccf5be5252fad0813c3b7`. Base: `6d4537f3e85a915c3d1c9d036d62fbcc6eae3cf4`.

**Verdict: PASS. Both migration findings below are fixed; no unresolved blocking source finding.** This is an independent source/targeted review. Root owns completion of the full host and actual current-head CI merge gates.

## Findings and fixes

1. **Legacy unindexed bodies could still replay after the rule upgrade.** The initial version bump purged only `http_cache_index` members, but reads accepted any hashed body by URL. A historical body write could have landed before its index write failed. Independently reproduced both an empty index and an indexed-sibling case, where the sibling was purged and the global version advanced but the orphan private body was still replayed with zero network visits. Raw before-result: `1260-review-probe-before.log`, 2 failures / 5 passing controls. Fixed by requiring current index membership plus the current admission-policy stamp before reading a body, with read failures caught on Object. A stamp check alone would not have fixed the sibling case.
2. **A refused replacement write could incorrectly certify a legacy private body.** On candidate `029ff21f6bd4563b60c487368d7824624da1cd72`, the index/stamp guard fixed both initial probes, but `_cacheResponse` ignored false from the body write. The first anonymous request correctly missed an unindexed legacy body and received a public network response; a refused replacement write left the old body while timestamp/index/version 3 were still written. The next request replayed that old private payload. Raw before-result: `1260-review-probe-write-refusal-before.log`, 1 failure / 7 passes. Fixed by requiring successful body and timestamp writes before index admission, and catching Object for write failures.

The implementer added committed real-ApiClient regressions for both orphan cases and refused replacement writes. Their legacy-key fixtures now include the same API-version prefix as the real client; otherwise a test could miss the intended stored key. Readable-cache mock fixtures now seed both index membership and policy stamp, preserving the existing cache-hit/stale/error assertions rather than weakening them. The fragment rule-version test now refers to the shared version constant; the separate fingerprint/version test still pins the actual rule/version relationship.

## Independent runtime results

Command: `/Users/nguyenanhkiet/Playground/flutter-starter/.git/codex-issue-work/sdk-350/flutter/bin/flutter test .git/codex-issue-work/1260-review-probe_test.dart --reporter expanded`

Final result: exit 0, **all 8 tests passed**. Raw output: `1260-review-probe.log`; source: `1260-review-probe_test.dart`.

- Refused body replacement cannot certify/replay a legacy private body.
- Unindexed legacy body with an empty index is not replayed.
- Unindexed legacy body with an indexed sibling is not replayed after the global stamp advances.
- Mixed-case `x-aPi-kEy` bypasses read/write across credentials.
- Normalized `x-auth_token` bypasses read/write across credentials.
- Custom fragment-matched `X-Custom-Secret` bypasses read/write across credentials.
- Multi-line/comma-separated Vary including `*` is not stored.
- Anonymous GET without Vary still reuses its public cached response.

The final passing run executed the production source now committed at the final HEAD. The subsequent commit only sealed that same production change and corrected a test-helper brace lint; I inspected the complete final base-to-head diff and `git diff --check` exits 0. No duplicate full-suite run was performed by this reviewer.

## Source assessment and limits

The extracted public sensitive-header predicate preserves the logger's prior trim/case/normalized-fragment matching and is reused for cache reads and writes. The version-3 rule fingerprint includes the explicit sensitive-header roster, so adding a header also participates in migration-version verification. Stored session credentials continue to bypass cache independently of interceptor order.

The URL-only key represents no request-header fields, so refusing any nonempty Vary field is conservative and correct. Nonempty/multi-line/comma-separated fields and `*` refuse storage and evict a prior entry at that URL. Anonymous responses without variant fields remain cacheable.

The migration validates removal/index/stamp boolean results and skips cache use if a purge fails; a failed purge is retried. The read guard refuses unindexed or old-policy bodies. Successful body and timestamp writes now precede admission metadata, preventing stale payload certification after a rejected replacement write.

Docs and class comments describe the shared rule and explicit no-store bypass for application-specific credential names that do not match it. The docs accurately limit physical cleanup to indexed bodies: historical unindexed preference data cannot be enumerated through this storage contract, is never reused, and can remain until refetch/overwrite or app-data clear. The probes establish cache/request behavior on host storage and fake transport, not physical device backups or server header correctness. All probe values are fixed synthetic fixture strings.

I read live issue #1260 acceptance criteria and status: open, assigned only to koniz-dev, exactly one `status:in-progress`. No tracked source, tests, docs, Git state or outbound comments were changed by this reviewer. Only scratch probes/reports under `.git/codex-issue-work` were written.
