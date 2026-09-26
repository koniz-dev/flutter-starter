# Issue 167 - strip-smoke no longer runs a full Flutter matrix on docs-only PRs

Shipped in PR [#230](https://github.com/koniz-dev/flutter-starter/pull/230),
merged as `fe27a5b`. Verification ran against that merged state of `main`.

`.github/workflows/strip-smoke.yml` keeps its unconditional `pull_request`
trigger - the three `Strip <variant> + analyze + test` checks still report a
conclusion on every pull request, which is what koniz-dev/flutter-starter#58
needs to mark them required. The filter moved inside each job, into a new
"Decide the strip scope" step, exactly as koniz-dev/flutter-starter#117 did for
the Quality gate in `ci.yml`.

## Evidence

| File | What it is |
|---|---|
| `criterion-1-2-docs-only-skip.log` | `gh pr checks` and the scope-step output for all three Strip jobs on the docs-only pull request that carried this directory |
| `criterion-3-full-run-and-red-variant.log` | `gh pr checks` and scope-step output for demo pull request #231, plus the failing `Analyze stripped tree` step |
| `criterion-4-path-filter-probe.log` | Local replay of the filter over twelve representative diffs |
| `format.log`, `analyze.log`, `tests.log` | `./scripts/test/run_acceptance.sh 167 --no-goldens` |

Run with `--no-goldens`: this change touches a workflow file and two markdown
documents. Nothing renders, so no golden could be evidence for any criterion,
and no PNG is present in this directory. No criterion rests on a golden.

## Criterion 1 - a docs-only PR installs no Flutter toolchain in any Strip job

`criterion-1-2-docs-only-skip.log`. The pull request that carried this evidence
directory is docs-only (`docs/verification/issue-167/**`, all `.md` and `.log`).
Each of the three Strip jobs printed

```
Strip smoke [<variant>]: SKIPPED (docs-only) - Every changed path matches
`**/*.md` or `docs/**` (and none is a `.dart` file), so no strip variant could
have been affected. strip, analyze and test were NOT run, and Flutter was NOT
installed.
```

and the job log contains no `Setup Flutter`, `Apply strip`, `Analyze stripped
tree` or `Run tests (stripped tree)` step output - every one of them is gated on
`steps.scope.outputs.run == 'true'`. The elapsed time per Strip job dropped from
roughly 2m30s to seconds; the log records the actual numbers.

## Criterion 2 - the three Strip checks still report a conclusion

`criterion-1-2-docs-only-skip.log`, `gh pr checks` section. All three of

- `Strip both-samples-removed + analyze + test`
- `Strip tasks-removed + analyze + test`
- `Strip feature-flags-removed + analyze + test`

are present with a `pass` conclusion on the docs-only pull request. A suppressed
workflow run would have shown none of them, which is the deadlock #117 had to
undo for `ci.yml`.

## Criterion 3 - a PR touching tool/ still runs all three in full, and a broken golden goes red

`criterion-3-full-run-and-red-variant.log`. Demo pull request
[#231](https://github.com/koniz-dev/flutter-starter/pull/231) changed exactly one
file, `tool/golden/no_tasks/lib/core/routing/app_routes.dart`, appending a
reference to an undefined symbol. It was closed unmerged; it existed only to
produce this log.

- Every Strip job printed `RAN IN FULL - 1 changed path(s) can affect a stripped
  tree`, listing that path.
- `Strip tasks-removed` went **red** at `Analyze stripped tree`: the golden had
  been copied over `lib/core/routing/app_routes.dart` and
  `flutter analyze` reported `Undefined name 'undefinedSymbolForIssue167'` plus
  `const_initialized_with_non_constant_value`, exit code 1.
- `Strip both-samples-removed` (2m24s) and `Strip feature-flags-removed` (2m35s)
  stayed green, because `fail-fast: false` keeps one broken variant from hiding
  the other two, and neither copies the `no_tasks` golden.

The fix pull request #230 itself is the second half of this criterion: it touched
`.github/workflows/strip-smoke.yml`, and all three Strip jobs ran in full
(2m27s, 2m37s, 2m46s) rather than taking the skip path.

## Criterion 4 - the trigger set is stated, with reasons, and a green check is readable

Two parts.

**Stated with reasons.** `.github/workflows/strip-smoke.yml` carries a
`WHICH PATHS TRIGGER A FULL STRIP RUN` comment block immediately above the scope
step. It names the rule (a deny-list, so an unlisted path fails safe and runs the
matrix) and then enumerates the trigger set entry by entry with why each one is
in it: `lib/**` is the tree being stripped, `tool/**` holds the strip script and
the goldens copied over `lib/` (the #50 failure), `test/**` and
`integration_test/**` must still pass after stripping, `examples/**` is analyzed
with the package, `pubspec.yaml` / `pubspec.lock` / `analysis_options.yaml`
change what pub get and analyze do, `.github/workflows/**` means a change to the
gate proves itself through the gate, `docs/**/*.dart` because
`analysis_options.yaml` does not exclude `docs/`, and everything else because it
is not obviously inert.

`criterion-4-path-filter-probe.log` replays the filter over twelve diffs and
confirms the two directions: only `**/*.md` and non-`.dart` `docs/**` skip; a
`.dart` file under `docs/` does not.

The probe is a literal copy of the filter body from the workflow. It is quoted
here rather than committed as a file, because a `.dart` or script probe under
`docs/verification/` is its own defect class (koniz-dev/flutter-starter#187):

```bash
#!/usr/bin/env bash
# Replays the "Decide the strip scope" filter from
# .github/workflows/strip-smoke.yml against a newline-separated path list on
# stdin, and prints the run= decision.
set -euo pipefail
changed="$(cat)"
relevant="$(
  {
    printf '%s\n' "$changed" | grep -Ev '^(docs/.*|.*\.md)$' || true
    printf '%s\n' "$changed" | grep -E '^docs/.*\.dart$' || true
  } | grep -v '^$' | sort -u || true
)"
if [ -n "$relevant" ]; then
  echo "run=true  ($(printf '%s\n' "$relevant" | wc -l | tr -d ' ') relevant: $(printf '%s ' $relevant))"
else
  echo "run=false (all inert)"
fi
```

**Readable from a green check.** The scope step prints a one-line headline to the
job log and to the GitHub step summary: `RAN IN FULL` or `SKIPPED (docs-only)`,
followed by the resolved diff range and a collapsed list of every changed path.
Both forms appear in `criterion-1-2-docs-only-skip.log` (skipped) and
`criterion-3-full-run-and-red-variant.log` (ran). The check *name* cannot carry
this, because GitHub derives it from the matrix, so the summary is the place a
reviewer looks.

## Criterion 5 - audit_template.sh exits 0

`format.log` (`dart format --set-exit-if-changed lib test integration_test tool
examples`, 365 files, 0 changed, `exit: 0`), `analyze.log` (`No issues found!`,
`exit: 0`), `tests.log` (`+2794 ~8: All other tests passed!`, `exit: 0`). Those
are the three gates `./scripts/dev/audit_template.sh` runs, driven here by
`./scripts/test/run_acceptance.sh 167 --no-goldens`, which reported
`RESULT: all gates passed.`
