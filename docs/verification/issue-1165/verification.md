Completed the delivery tracker and published [v4.0.0](https://github.com/koniz-dev/flutter-starter/releases/tag/v4.0.0).

| Acceptance criterion | Result and artifact |
|---|---|
| Every sub-issue is closed with evidence | PASS — [children.json](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1165/children.json) shows exactly #1166–#1172 closed; [merged-delivery.json](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1165/merged-delivery.json) links all seven merged PRs and committed verification reports. |
| Release child closed and version is Latest | PASS — #1172 is closed; [release-list.log](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1165/release-list.log) and [latest-release.json](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1165/latest-release.json) identify v4.0.0 as Latest. Notes match the frozen changelog. |
| Main CI and Strip smoke green on release commit | PASS — [main-runs.json](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1165/main-runs.json) records success on `b1d2d49184abd019aa8036d96ac38605d3fe1ada`. The marker commit is Markdown-only: Quality ran 654 documentation tests; Strip skipped internal runtime work. Earlier fix PRs ran all five Strip variants; separate host acceptance ran 4,227 tests successfully (14 skips). |
| Original local branch deleted or residual diff accounted | PASS — [candidate-accounting.md](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1165/candidate-accounting.md) maps all 12 paths to delivered PRs and explains the three reviewed extensions; [candidate-to-release.patch](https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-1165/candidate-to-release.patch) preserves the full residual diff. The immutable local recovery snapshot is retained. |

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

Self-QA inspected the child evidence, release body/tag, exact-commit CI conclusions and complete candidate diff. No new source change is introduced by this aggregate closure. Main is clean and synced. No screenshots were collected; no criterion rests on standing goldens or a device/backend/store claim.
