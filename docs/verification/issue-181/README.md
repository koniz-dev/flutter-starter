# Acceptance evidence - issue #181

`fix(auth): a failure whose message merely contains "refresh" forces a logout
regardless of its error code`

Verified against `main` after PR #240 merged (`63959ad5b83`).

## What changed

`AuthNotifier.refreshToken()` used to force a logout on
`failure.code == 'REFRESH_TOKEN_EXPIRED' || failure.message.toLowerCase().contains('refresh')`.
The decision now reads `failure.code` alone, and
`AuthRepositoryImpl.refreshToken()` sets that code on every outcome that means
the refresh token is dead.

## Criterion map

| # | Criterion | Artifact |
|---|---|---|
| 1 | no `contains('refresh')` in the notifier; decision reads structured state | `criterion-1-no-substring-match.log` |
| 2 | a non-`REFRESH_TOKEN_EXPIRED` failure messaged "Please refresh and try again" leaves the session alive; red on the pre-fix decision | `criterion-2-red-run-prefix-condition.log` (red), `criterion-5-auth-network-tests.log` (green) |
| 3 | `code == REFRESH_TOKEN_EXPIRED` logs out and clears the session | `criterion-5-auth-network-tests.log` |
| 4 | every forced-logout path sets the code explicitly | `criterion-4-code-origins.log` |
| 5 | `flutter test test/features/auth/ test/core/network/` exits 0 | `criterion-5-auth-network-tests.log` |
| 6 | `./scripts/dev/audit_template.sh` exits 0 | `criterion-6-audit_template.log` |

`analyze.log`, `format.log` and `tests.log` are the standard
`scripts/test/run_acceptance.sh 181 --no-goldens` output. No goldens were run:
this change renders nothing.

## How the red run was produced

Criterion 2 asks for the test to be shown failing against the pre-fix decision.
No `.dart` probe is committed here (issue #187); the exact edit was a one-line
revert of the merged notifier, applied to a scratch copy:

```diff
--- a/lib/features/auth/presentation/providers/auth_provider.dart
+++ b/lib/features/auth/presentation/providers/auth_provider.dart
-        if (failure.code == AuthErrorCodes.refreshTokenExpired) {
+        if (failure.code == AuthErrorCodes.refreshTokenExpired ||
+            failure.message.toLowerCase().contains('refresh')) {
           await logout();
         }
```

That is `main`'s condition before this fix, character for character apart from
the constant's name. Nothing else was changed - the repository's new codes stay
in place, which is why the red run is specifically about the notifier's
decision. Three tests fail:

- `should keep the session when an unrelated failure mentions refresh`
- `should keep the session when a newer session ended the refresh`
- `should not logout on an untagged failure naming refresh`

All three pass with the merged notifier.

## Which refresh outcomes force a logout

| Outcome | Before | After |
|---|---|---|
| `code == REFRESH_TOKEN_EXPIRED` | logout | logout |
| no refresh token stored (`"No refresh token available"`) | logout, by accident of the substring | logout, by the code the repository sets |
| 401 from the refresh endpoint (`"Unauthorized. Please login again."`) | no logout - no "refresh" in the message | logout |
| `SESSION_TERMINATED` (`"Session ended while the token refresh was in flight"`) | logout, clearing a session that had already been replaced | no logout |
| transient error phrased "Please refresh and try again" | logout | no logout |
| timeout, 5xx, decode error | no logout | no logout |

No path lost forced logout. The 401 gained it.
