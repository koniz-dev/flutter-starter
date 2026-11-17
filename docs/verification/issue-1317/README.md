# Issue 1317 - starter v5.0.0 published

| Criterion | Artifact | Result |
|---|---|---|
| 1. Non-PR workflows pass on the release code | `release-checks.txt`: E2E Android (Patrol), Build (Manual: Android, iOS no-codesign, Web, JDK 25), Coverage Analysis on `ceae85cff40`; Scripts smoke (all four jobs) on the release commit `8fe1730333b` | all success. The first Scripts smoke run found #1319 (Option B tests); fixed in PR 1320 before release |
| 2. Version follows semver | comment on the issue | v5.0.0 (major): 10 Breaking entries |
| 3. Changelog frozen, marker bumped by a green PR | maintainers `ef83b5737b2` (`## [5.0.0] - 2026-11-17`, 66 entries); PR 1318 squash `8fe1730333b` | done |
| 4. `release_starter.sh` dry run, then real | dry run printed `release v5.0.0 -> 8fe1730333b...` and the notes; the real run published | done |
| 5. Release shows the notes and is Latest | `release-checks.txt` (`gh release list`) | v5.0.0 Latest, tag at `8fe1730333b` |

Between `ceae85cff40` and `8fe1730333b` only PR 1320 (test-only) and PR 1318 (one markdown line) landed; both had green Quality gate and Strip, and Scripts smoke ran on the release commit itself.
