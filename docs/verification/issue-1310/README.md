# Issue 1310 - P3 findings of the 2026-11-17 audit

All 15 boxes ticked by merged changes: PR 1313 (tooling), 1314 (docs), 1315 (network/auth), 1316 (UI). Gates on `main` at `ceae85cf fix(ui): close the layout and navigation findings of the 2026-11-17 audit (#1316)`.

| Box | Artifact | Result |
|---|---|---|
| OptimizedListView: prefetch after failure, itemExtent slot, empty first page | `box_tests.log` (`optimized_list_view_paging_defects_test.dart`) | pass; each fails before its fix; review follow-ups (insets, parent Retry, empty+error) covered |
| RouteNotFoundScreen overflow | `box_tests.log` (`route_not_found_overflow_test.dart`) | no overflow at 2.0x/640x360, 400 and 4000 chars |
| Feature flags debug row | `box_tests.log` (`feature_flags_debug_row_wrap_test.dart`) | no overflow at 1.0x/1.3x on 360dp (Ahem); real-font arithmetic fits 2.0x |
| Nested redaction | `box_tests.log` (`nested_query_redaction_test.dart`) | raw and encoded nesting redacted, linear time; `#code?x=` struck with reason |
| Task id encoding | `box_tests.log` (`task_id_encoding_test.dart`) | id `a/b?c#d e` round-trips both ways in |
| Late logout vs newer sign-in | `box_tests.log` (`auth_provider_test.dart`, "a logout that completes after a newer sign-in") | sign-in kept |
| strip_rerun_test diagnostics | `box_tests.log` (`strip_rerun_test.dart`); review ran it with HEAD unresolvable | full git output, no PathNotFoundException; root cause of the CI failure still unknown |
| Push runs not cancelled | `workflow-concurrency.txt`, `box_tests.log` (`workflow_hardening_test.dart`) | six push workflows grouped per sha, cancel only on pull_request |
| grep -c single count | `workflow-concurrency.txt` | `[0]` |
| check_docs link forms / dart test | `box_tests.log` (`check_docs_link_scope_test.dart`, `doc_test_paths_test.dart`) | broken links in all forms fail; valid ones pass |
| test_coverage.sh installs nothing | `box_tests.log` (`test_coverage_no_install_test.dart`) | pass |
| Brick prose after --remove-bricks | `box_tests.log` (`strip_bricks_prose_test.dart`); stripped copy grep in PR 1314 | no unmarked instruction |
| audit.md ratings | `docs/guides/security/audit.md` at `ceae85cf fix(ui): close the layout and navigation findings of the 2026-11-17 audit (#1316)` | re-rated with concrete facts |
| Host gates (G2) | `audit_template.log`, `epic.log`, `deliverable.log`, `refs.log`, `summary.txt` | all exit 0; 4684 passed |

No screenshot is cited; the acceptance goldens are not part of this evidence.
