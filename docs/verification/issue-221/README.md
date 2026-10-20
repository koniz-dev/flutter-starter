# Acceptance evidence - issue #221

`refactor(core-di): core/di/providers.dart and features/auth/di import each
other, and core re-exports all three feature DI surfaces`

Verified against `main` after PR #242 merged (`6ff691556a4`).

## What changed

`authInterceptorProvider` moved into `lib/core/di/providers.dart`, beside the
`apiClientProvider` that installs it. The two dependencies it has on the auth
feature became ports core declares and the feature fills:

| Port (core) | Default when unwired | Filled by (`authModuleOverrides`) |
|---|---|---|
| `tokenRefresherProvider` | a failure with code `NO_TOKEN_REFRESHER` whose message names the missing override | `() => ref.read(authRepositoryProvider).refreshToken()` |
| `sessionTerminationSinkProvider` | `null`, the degraded path `AuthInterceptor` already documents | `RiverpodSessionTerminationSink` |

`createAppContainer()` in `lib/main.dart` applies `authModuleOverrides`. The
three backward-compatibility re-exports are gone, and the files that leaned on
them import the feature DI file directly.

## Criterion map

| # | Criterion | Artifact |
|---|---|---|
| 1 | no feature URI in `lib/core/di/providers.dart` | `criterion-1-no-feature-uri.log` |
| 2 | allowlist entry deleted, the other two untouched, guard green | `criterion-2-allowlist.log` |
| 3 | every former re-export consumer resolves; `flutter analyze` clean | `criterion-3-imports-resolve.log` |
| 4 | runtime graph unchanged where it was load-bearing | `criterion-4-runtime-graph.log` |
| 5 | all three strip variants still analyzable | `criterion-5-strip-variants.log` |
| 6 | `./scripts/dev/audit_template.sh` exits 0 | `criterion-6-audit_template.log` |

`analyze.log`, `format.log` and `tests.log` are the standard
`scripts/test/run_acceptance.sh 221 --no-goldens` output. No goldens were run:
this change renders nothing, and the directory contains no `.png`.

## Judgement calls

**Why not a rule-level exemption.** `lib/core/routing/routes_registry.dart`
already has one, baked into `_coreImportsFeature` as a designated seam. Giving
the DI module the same treatment would have satisfied criterion 1 (which only
constrains `providers.dart`) while leaving the edge in place, and the guard's
stale-exemption check - the thing criterion 2 calls "what proves the edge is
actually gone" - would never have fired. The allowlist line was deleted instead
and the edge genuinely removed.

**Why the unwired refresher returns a failure instead of throwing.** It is
invoked from `AuthInterceptor`'s error path. A throw there would replace a
recoverable 401 with an unhandled async error. A failure carrying
`NO_TOKEN_REFRESHER` ends in a forced logout, which is the safe direction for an
app whose session cannot be renewed, and the message names the override to add.

**Three tests were passing vacuously.** `forced_logout_session_test.dart` and
`auth_interceptor_session_generation_test.dart` build their own
`ProviderContainer`s. Without `authModuleOverrides` they would have run against
a null sink and the seam's default refresher - still green, proving much less
than they read. They now pass `...authModuleOverrides`, which is why those files
appear in the diff.

**`_patchProviders` deleted from `tool/strip_sample_features.dart`.** Its only
job was stripping the two feature re-export lines from `providers.dart`, which
no longer exist. Leaving it would have left a no-op that silently stopped
meaning anything.
