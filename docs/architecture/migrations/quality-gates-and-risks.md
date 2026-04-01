# Quality Gates, Risk Register, and Verification Checklist

## Global Quality Gates (apply to every phase)
- No user-facing behavior regressions in smoke and regression tests.
- No new lint errors in changed files.
- Backward compatibility path exists for one internal release cycle.
- Each migration increment can be rolled back without reverting unrelated features.
- Updated docs for contracts, adapters, and enablement steps.

## Phase-specific Quality Gates

### Network
- No feature/data layer imports `package:dio/dio.dart`.
- `INetworkClient` contract tests pass across success/error/timeout scenarios.
- Auth refresh behavior remains stable.

### Storage
- Auth and interceptor token flows pass existing tests.
- Token clear/invalidate behavior remains deterministic.
- Migration service supports both legacy and new contracts during transition.

### Navigation
- Auth redirects are validated by policy tests.
- Critical routes (login/home/tasks) preserve path behavior.
- No direct router calls in migrated feature orchestrators.

### Theme/Token
- `AppTheme` output remains visually consistent (baseline screenshots if available).
- New widgets consume semantic tokens, not hardcoded colors/typography.

### State
- Controller contract tests pass independent of Riverpod container wiring.
- Existing providers remain functional until full migration completion.

## Risk Register

| Risk | Impact | Likelihood | Mitigation | Rollback Trigger |
|---|---|---|---|---|
| Error mapping mismatch after de-Dio | High | Medium | Contract tests for error normalization | Authentication/network tests fail |
| Token lifecycle regression | High | Medium | Dedicated token store tests + auth regression suite | Login/refresh/logout flow fails |
| Redirect behavior drift | High | Medium | Extract and test redirect policy separately | Route guards misroute users |
| Theme visual regressions | Medium | Medium | Side-by-side theme snapshot checks | Major UI inconsistency detected |
| State sync issues during mixed mode | Medium | Medium | Migrate feature-by-feature with adapter boundaries | Provider/controller state diverges |

## Verification Checklist (per increment)
- [ ] Scope limited to one boundary increment.
- [ ] Unit/contract tests added or updated.
- [ ] Existing regression tests for touched feature are green.
- [ ] Lint clean for modified files.
- [ ] Docs updated (`architecture`, `api`, and setup notes if needed).
- [ ] Rollback note documented in PR description.
