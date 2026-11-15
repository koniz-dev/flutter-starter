# Independent adversarial premerge review: issue 1262

Reviewed on 2026-11-15. Base: `e2e848b51354c0beee82c4f3d984d25d9ca539fb`. Branch: `codex/fix-immediate-sign-out-state`. Initial scope: uncommitted changes to auth_provider.dart, generated auth_provider.g.dart, HomeScreen comment, and manual_logout_session_test.dart. Final reviewed head: `90866bb32421dc43bdf07ea0ae8eb9493ddb6d4a`, PR https://github.com/koniz-dev/flutter-starter/pull/1272. Final tree clean; all five reviewed file hashes match the committed head. No source changes since the four-probe run; no duplicate run needed.

Read CLAUDE.local.md, CLAUDE.md, maintainer process.md, issue-workflow.md, and qa/security role instructions. Read actual issue via read-only REST bridge.

## Findings

- HomeScreen's explanatory comment initially drifted from its stripped counterpart. Reported to implementer; reinspection confirms the counterpart now carries the same new explanation. Resolved in working diff. This was documentation/convention drift, not a proven CI failure.
- No additional actionable code or security regression found in the reviewed change.

## Independent checks

Ran the private probe `.git/codex-issue-work/1262-race-probe_test.dart` with the absolute local Flutter 3.50 binary, `flutter test --no-pub ... --reporter expanded`; exit 0, 4 tests passed. Log: `.git/codex-issue-work/1262-race-probe.log`.

The private test includes both submitted widget regressions and two additional queued-sign-in adversarial probes using the actual repository/provider/router graph. In each additional probe, logout remains remotely pending after local teardown, LoginSubmit is disabled, a programmatic login B starts and does not call the remote login while logout is tracked, then logout completes (one success, one server failure). Login B subsequently succeeds, retains access-B, routes Home, clears old logout failure, and is not erased by the old logout completion.

Inspected repository generation checks for in-flight sign-in and restore: logout invalidates synchronously before any data await, stale sign-in persistence checks generation, and getCurrentUser checks after token/user reads. Production boot awaits restoration before UI; no additional restore call site was introduced. UI login/register navigation and submission stay disabled while pending logout sets isLoading. Home button completion checks mounted, so prompt router disposal does not setState after disposal.

Reviewed actual local/remote failure semantics: repository clears credentials and response cache before remote await, captures old access/refresh for remote revocation, executes independent cleanup steps, and gives local failure precedence. Changed notifier continues to await and report the Result, while immediately dropping user; failure cannot reinstate the old user. No new token logging, dependency/network destination, or secret exposure was introduced.

`git diff --check` passed. No tracked files or Git state modified by this reviewer. No full-suite, golden, device/backend, or pre-fix negative-control claims; implementer owns those checks. No outbound messages/changes made.

## Reviewed working-file SHA-256

- `lib/features/auth/presentation/providers/auth_provider.dart`: `edec1fc41e129e61853f1c14421a3c0570f79aafa08a17f0ae6d0fc2a70da4fc`
- `lib/features/auth/presentation/providers/auth_provider.g.dart`: `643a9c0e865a2d9c545b75d46e2bc86ade96db5b5a7ac2e1be23142491cc0bef`
- `lib/features/home/presentation/screens/home_screen.dart`: `3fc97a5dcc47f8af6987568979164032a024ac782837edb23d7357d7e1e04df5`
- `tool/golden/stripped/lib/features/home/presentation/screens/home_screen.dart`: `3fc97a5dcc47f8af6987568979164032a024ac782837edb23d7357d7e1e04df5`
- `test/features/auth/manual_logout_session_test.dart`: `bbc5998ed5f0ec768793fea8a98f1f32f93e22542a0f00bf6741d65dd84fa889`

Final candidate confirmation: reviewed `e2e848b51354c0beee82c4f3d984d25d9ca539fb..90866bb32421dc43bdf07ea0ae8eb9493ddb6d4a`; no remaining premerge findings. Root-reported audit, golden and CI results are not independently rerun or asserted by this review.
