# Independent auth documentation review

Issue: koniz-dev/flutter-starter#1263
Reviewed base: `6699ce7f381bce67da5945b071e4c047fd68ee54`
Reviewed final head: `4ea66476370637d983865b16e2973316d7b36cba`
PR: https://github.com/koniz-dev/flutter-starter/pull/1273
Final binding: HEAD and the five-file base-to-head diff inspected after commit; tracked working tree clean and documentation/test contents unchanged from the independent targeted verification.

## Outcome

No actionable defects found in the four corrected documentation files and `test/docs/auth_flow_examples_test.dart`. This was an independent read of the issue acceptance criteria, actual working diff, published provider/session graph, remote datasource and repository implementation, bootstrap scope, architecture guard and snippet analyzer. No tracked files or outbound service state were modified by this review.

## Findings checked

- Complete login uses the notifier and publishes the user to the same auth state that session status/router observe. It watches notifier loading state, disposes text controllers, localizes failures, and leaves successful deep-link routing to the router. The existing self-contained snippet analyzer compiles the entire example; the new runtime case selects its quoted API shape and executes the corresponding typed WidgetRef call against real session status and token storage.
- Core session blueprint injects a `Future<void> Function()` sign-out seam and imports only core contracts. Its declared placement passes the existing architecture guard. The feature lifecycle wrapper resolves token storage and sign-out inside the configured app scope, preserves the existing child/router/localization, registers/removes its observer, and disposes its timer. Both blueprint pieces analyze together without assuming the optional core file already exists. The sign-out regression uses the configured authModuleOverrides and proves both token clearing and visible signed-out state.
- Logout table accurately describes optional refresh-token body and captured access-token bearer header, matching AuthRemoteDataSourceImpl.logout and repository capture-before-local-cleanup ordering.
- Both manual refresh examples check only AuthErrorCodes.refreshTokenExpired before calling signOutProvider, do not rewrite persisted credentials, and explicitly preserve newer sessions on SESSION_TERMINATED. API imports and result extensions resolve.
- New markdown-reader regression is covered by CI's existing test/docs path. No workflow expansion is necessary.

## Independent verification

Command (Flutter 3.50 SDK bin prefixed on PATH):

```sh
flutter test test/docs/auth_flow_examples_test.dart test/docs/api_integration_snippets_test.dart --reporter expanded
```

Captured tool-output transcript: `.git/codex-issue-work/1263-independent-tests.log` (persisted from completed tool results without rerunning tests).

Result: exit 0, all 6 tests passed (five auth flow cases and existing full integration snippet analyzer). `git diff --check` also exited 0. The parent runs the broader audit; this review did not duplicate the full suite.

## Scope limits

Host-side documentation/API/session mechanism review only. The optional existing illustrative timeout policy is not a complete idle-timeout implementation or real-device/backend security certification. No app runtime source changes were introduced.


# Postmerge independent QA/security review

Issue: koniz-dev/flutter-starter#1263
PR: https://github.com/koniz-dev/flutter-starter/pull/1273
Accepted head: `4ea66476370637d983865b16e2973316d7b36cba`
Merged main: `ec3a05407e1cf997bb689dc19a85f8d82ee9708a`

## Outcome

PASS for the scoped documentation/API/session mechanisms. No actionable introduced defects or additional security findings. `git diff --exit-code` between accepted head and merged main passed, confirming tree parity. REST reports PR merged at this exact commit. The squash message carries `Refs koniz-dev/flutter-starter#1263`; the issue remains open/in-progress pending evidence publication/closure. No tracked or outbound state was modified by this review.

## Independent postmerge execution

With `.git/codex-issue-work/sdk-350/flutter/bin` prepended to PATH, ran:

```sh
flutter test test/docs/auth_flow_examples_test.dart test/docs/api_integration_snippets_test.dart --reporter expanded
```

All six tests passed, exit 0. Actual subprocess stdout/stderr, command and exit code are saved in `.git/codex-issue-work/1263-postmerge-independent.log`. Both generated snippet directories were removed by test cleanup; final `git status --short` was empty, and `git diff --check` passed.

## Evidence and criteria inspection

Read the actual evidence `format.log`, `analyze.log`, and `tests.log` under `/Users/nguyenanhkiet/Playground/flutter-starter-evidence/docs/verification/issue-1263`, plus the acceptance-runner source and summary, counterfactual log, docs-check log, root inspection and draft criteria mapping. Format reports 631 files unchanged; analyzer reports no issues; full-suite completion reports 4,494 passes, 14 skips and exit 0. The runner intentionally retains head/tail excerpts for passing long logs, so this review does not claim the evidence tests.log is an unabridged transcript. The separately saved postmerge focused log provides direct output for the issue-specific cases.

- Login: the quoted API selector executes the corresponding typed WidgetRef notifier call against the real session graph, and asserts persisted token plus SessionStatus.signedIn. The complete login block analyzes independently. The baseline log shows the usecase-only example instead leaves signedOut.
- Blueprint: the declared core placement is checked by the actual import-rule functions, both optional pieces compile together, and the configured signOutProvider action clears credentials and publishes signedOut. The baseline shows both the core-to-feature import failure and signedIn after repository-only logout. Scope/lifecycle wiring and cleanup were read against the actual bootstrap/provider graph.
- Logout: corrected refresh-token body and bearer note match the datasource/model contract and capture-before-cleanup repository behavior. The focused regression checks both documentation fields; the docs checker passes.
- Refresh: both examples use AuthErrorCodes.refreshTokenExpired, avoid redundant token persistence, preserve newer sessions for SESSION_TERMINATED and expose results for caller handling. Static regression and snippet analyzer pass.

No screenshot is used as wording or behavior proof; the nonvisual acceptance run skipped golden execution and collection. Scope remains host-verifiable starter mechanisms; existing illustrative timeout policy and real-device/live-backend behavior are not certified.

The existing premerge independent review remains valid because the merged tree is identical to the accepted tree. Final evidence commit/push and issue closure remain the owning session's publication steps.

