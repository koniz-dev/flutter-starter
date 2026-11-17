# Issue 1323 - the silent git archive exit in strip_rerun_test

| Criterion | Artifact | Result |
|---|---|---|
| 1. Stress on ubuntu-latest, logs kept, branch deleted | `stress-summary.txt`, `stress-shard1-round1.log` (run 44086867809) | 40 rounds of the full `test/tooling` suite in random order: `strip_rerun_test` 1000 executions (1000 fixture `git archive` calls), probe 12000 `git archive` calls - 0 failures, 0 Dart child-error lines. The 2 tests that failed every round did so because of the temporary workflow and `test/zz_stress/` themselves (CLAUDE checks/README tree listing, push-workflow concurrency rule). Branch deleted. |
| 2. Mechanism named, or the residual stated | analysis below; CI history scan `ci-*-runs-scanned.txt` | not captured; residual outside this repository |

## Analysis

- One occurrence in the last 400 `ci.yml` runs (run 44004786456 attempt 1), 0 in 1000 + 12000 stressed spawns on the same runner image, 0 in 450+ local attempts.
- git (master `builtin/archive.c`, `archive.c`, `archive-tar.c`, `git.c`): every error path for a local tar archive prints and exits 128 or 255; no path exits 1 with empty stderr.
- No test writes to the real repository's git state or changes the process working directory.
- Dart VM `runtime/bin/process_linux.cc` `NewProcess()`: the forked child `_exit(1)`s before `exec` if its start-notification read fails, with `perror` going to the parent's inherited stderr, not to the command's captured stderr - the only path found that yields exit 1 with empty stderr. Not observed in any log, so not proven.

Conclusion: the failure originates below the repository's code (process spawning in the VM or runner) and is not reproducible at a rate observable here. Since PR 1313, `_copyOfHead` reports exit code, stdout and stderr of any failing step and cleans up, so a recurrence is diagnosable rather than masked.
