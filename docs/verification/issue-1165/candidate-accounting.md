The local recovery branch `codex/delivery-audit-2026-11-08` is intentionally retained at immutable snapshot `97cbf6a6a3a763d9b6e4f29a52fff50e992b4daa`. Its original base was `7e6170aa07c`; it was not pushed. Current working checkout is clean `main` at release `b1d2d49184abd019aa8036d96ac38605d3fe1ada`.

All 12 original candidate paths are delivered through the following child PRs; no candidate functionality remains unshipped.

| Original candidate path | Delivery issue / PR |
|---|---|
| `android/.gitignore` | #1171 / PR #1182 |
| `lib/core/contracts/storage_contracts.dart` | #1170 / PR #1181 |
| `lib/core/storage/migration/migrations/migration_v1_to_v2.dart` | #1166 / PR #1173 |
| `lib/core/storage/storage_service.dart` | #1166 / PR #1173 |
| `lib/features/auth/data/datasources/auth_local_datasource.dart` | #1167 / PR #1174 |
| `lib/features/tasks/data/datasources/tasks_local_datasource.dart` | #1168 / PR #1175 |
| `lib/features/tasks/presentation/providers/tasks_provider.dart` | #1169 / PR #1180 |
| `lib/features/tasks/presentation/providers/tasks_provider.g.dart` | #1169 / PR #1180 |
| `test/core/storage/migration/migrations/migration_rejected_write_test.dart` | #1166 / PR #1173 |
| `test/features/auth/data/datasources/auth_storage_rejection_test.dart` | #1167 / PR #1174 |
| `test/features/tasks/presentation/providers/tasks_session_reset_test.dart` | #1169 / PR #1180 |
| `test/features/tasks/presentation/providers/tasks_wipe_failure_test.dart` | #1168 / PR #1175, #1169 / PR #1180 |

Nine original candidate paths are byte-identical in the release. The remaining three are the tasks provider, its generated hash and wipe-failure tests: independent review led to settling pending cleanup before creating tasks, plus direct recovery, real-screen isolation and concurrent-wipe coverage. These additions shipped in #1168 and #1169. The generated hash matches the combined source.

The full candidate-to-release diff also includes the upstream crypto dependency bump already on main before these fixes, additional regression tests and the v4 marker. The archive remains based on the older commit and is not the active delivery branch. `original-candidate.patch` preserves its complete payload; `candidate-to-release.patch` records every residual difference for inspection.
