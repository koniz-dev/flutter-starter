# Issue 1324 - starter v5.0.1 published

| Criterion | Artifact | Result |
|---|---|---|
| 1. E2E Android and Build (all platforms) on the release code | `release-checks.txt` (runs 44086959967, 44086965783 on `3359e6d2f17`, which is the release commit minus its one-line marker change) | success; Patrol Total 2, Successful 2, Failed 0, Skipped 0 |
| 2. `[5.0.1]` frozen, marker PR green | maintainers `309dfbb52e2`; PR 1325 squash `c91c9a87efd` | done |
| 3. Dry run then release; Latest | `release-checks.txt` (`gh release list`) | v5.0.1 Latest, tag at `c91c9a87efd` |
