# Issue 1336 - publish starter v5.0.2

Release commit: `7c1e42df58a docs: mark starter v5.0.2 release (#1340)`.

| Criterion | Artifact | Result |
|---|---|---|
| `e2e-android.yml`, `build.yml` (all platforms) and `scripts-smoke.yml` pass on the release code | `workflow-runs.txt`: runs 44137027902 (E2E), 44137034821 (scripts smoke, four jobs), 44137041504 / 44137047550 / 44137054103 (Android with the JDK 25 job, iOS no codesign, Web), all on `7c1e42df58a`, all success. `e2e-summary.txt`: `Total: 2`, `Successful: 2`, `Failed: 0`, `Skipped: 0` | pass |
| `[Unreleased]` renamed to `[5.0.2] - <date>`, patch, nothing breaking | maintainers branch `history/starter-changelog.md`: `## [5.0.2] - 2026-11-18`, `### Fixed` only; `release-notes.md` is that section as published | done |
| `**Starter version:**` bumped to v5.0.2 through a PR with green checks | `marker-pr.txt` (PR 1340 merged as `7c1e42df58a`, every check SUCCESS); `marker-line.txt` | done |
| `release_starter.sh v5.0.2 --dry-run <commit>` then the real run succeed; v5.0.2 is Latest | dry run and real run both printed `release v5.0.2 -> 7c1e42df58ac...`; `release.txt` (tag v5.0.2, target `7c1e42df58ac...`), `tag.txt` (`refs/tags/v5.0.2` at the same commit), `release-list.txt` (v5.0.2 Latest) | done |

The earlier dispatch on `524ddea4f9f` (before PRs 1337-1340) also passed; it is superseded by the runs on the release commit above.

No screenshots; no golden is cited.
