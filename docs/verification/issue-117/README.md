# Verification - issue 117

`ci: the Quality gate never reports on a docs-only PR, so it cannot be a
required status check`

Shipped in PR [#154](https://github.com/koniz-dev/flutter-starter/pull/154),
squash-merged to `main` as `a45857b`.

## What changed

`.github/workflows/ci.yml` lost its workflow-level
`paths-ignore: ['**/*.md', 'docs/**']`. The filter moved into the job, to a new
`Decide the gate scope` step that diffs `base...head` (or `before..after` on a
push) and sets an output consumed by `if:` on **Setup Flutter**, **Install
dependencies**, **Verify formatting**, **Analyze code** and **Run tests**.

The job therefore runs on every pull request and always posts a conclusion,
which is what a required status check needs; on a docs-only change it does a
checkout and a `git diff` and stops, without installing the Flutter toolchain.

### Mechanism, and what was rejected

| Option | Verdict |
|---|---|
| Move the path filter into the job, `if:` on the expensive steps (**chosen**) | One job, one check context, one copy of the path list, no third-party action. |
| `dorny/paths-filter` plus a same-named dummy job | Rejected: adds a third-party action to a repository that risk-gates dependency changes, and emits two check runs sharing the name `Quality gate`, which branch protection cannot tell apart. |
| A separate `ci-skip.yml` shim with `paths:` mirroring `ci.yml`'s `paths-ignore` | Rejected: splits one gate's path list across two files that must be kept in sync by hand. When they drift, either both fire or neither does. |
| Change nothing; require an existing always-reporting check instead | Rejected: **Issue refs** checks commit-message hygiene, not code quality, and no **Strip** variant runs `dart format` - all three analyze and test a *stripped* tree, not the shipped one. `criterion-2-broken-code-pr-checks.log` shows this directly: the misformatted file turned Quality gate red while all three Strip jobs stayed green. |

### The skip set is narrower than the old `paths-ignore`

`.dart` is never inert, wherever it lives. `analysis_options.yaml` does not
exclude `docs/`, so `docs/verification/issue-48/aot_probe.dart` is analyzed by
`flutter analyze` like any other source. Under the old `paths-ignore` a broken
evidence probe would have sailed through the gate and reddened `main` on
somebody else's unrelated pull request later.

An unresolvable diff range - `workflow_dispatch`, a brand new branch, a force
push that dropped `before` - fails **safe** and runs the full gate.

### What a green Quality gate on a docs-only PR means

Not that `dart format`, `flutter analyze` and `flutter test` passed. It means
they **did not run**, because no changed path can affect them. The job summary
states which of the two happened and lists every changed path, so the
distinction is visible without reading the YAML. A reviewer should read it as
"nothing this gate guards could have changed", never as "the code is green".

## Criteria

| # | Criterion | Verdict | Artifact |
|---|---|---|---|
| 1 | A PR changing only `*.md` reports a passing **Quality gate** | PASS | [`criterion-1-docs-only-pr-checks.log`](criterion-1-docs-only-pr-checks.log), [`criterion-1-3-docs-only-quality-gate-run.log`](criterion-1-3-docs-only-quality-gate-run.log) |
| 2 | A Dart-code PR still runs format, analyze and test; a broken format fails the gate | PASS | [`criterion-2-broken-code-pr-checks.log`](criterion-2-broken-code-pr-checks.log), [`criterion-2-broken-code-quality-gate-failure.log`](criterion-2-broken-code-quality-gate-failure.log), [`criterion-2-code-pr-154-quality-gate-run.log`](criterion-2-code-pr-154-quality-gate-run.log) |
| 3 | The skip path installs no Flutter toolchain and finishes in under a minute | PASS | [`criterion-1-3-docs-only-quality-gate-run.log`](criterion-1-3-docs-only-quality-gate-run.log), [`criterion-3-run-durations.log`](criterion-3-run-durations.log) |
| 4 | Branch protection can list `Quality gate` without wedging docs-only PRs | N/A by the criterion's own escape clause - protection is still absent | [`criterion-4-branch-protection.log`](criterion-4-branch-protection.log) |
| 5 | `./scripts/dev/audit_template.sh` exits 0 | PASS | [`format.log`](format.log), [`analyze.log`](analyze.log), [`tests.log`](tests.log) |

### Criterion 1

Pull request
[#156](https://github.com/koniz-dev/flutter-starter/pull/156) was opened with a
one-file diff, `docs/verification/issue-117/docs-only-probe.md`. Its check list:

```
Docs check     pass   40s
Issue refs     pass    6s
Quality gate   pass    7s   run 36139123873
Strip both-samples-removed + analyze + test      pass  2m9s
Strip feature-flags-removed + analyze + test     pass  2m41s
Strip tasks-removed + analyze + test             pass  2m18s
```

The run log's scope step reads:

```
- event: `pull_request`
- range: `a45857b...ee42745`
- expensive steps run: `false`

Every changed path matches `**/*.md` or `docs/**` (and none is a `.dart`
file), so nothing this gate checks could have changed. format, analyze and
test were NOT run.
```

The before picture is pull request
[#136](https://github.com/koniz-dev/flutter-starter/pull/136) (19 files, all
under `docs/verification/issue-65/`): Issue refs and the three Strip jobs, and
no Quality gate at all.

### Criterion 2

Two directions, both driven for real.

**Red.** Pull request
[#155](https://github.com/koniz-dev/flutter-starter/pull/155) added a single
deliberately misformatted file, `tool/ci_probe_bad_format.dart`, and nothing
else. Quality gate **failed** in 24s:

```
Verify formatting   Formatted tool/ci_probe_bad_format.dart
Verify formatting   Formatted 356 files (1 changed) in 1.07 seconds.
Verify formatting   ##[error]Process completed with exit code 1.
```

All three Strip jobs passed on that same pull request - they do not run
`dart format` - which is why none of them is a substitute for this gate.
`gh pr checks 155` exits 1. The branch was never merged; it is deleted.

**Green.** Pull request
[#154](https://github.com/koniz-dev/flutter-starter/pull/154), the change
itself, touched `.github/workflows/ci.yml` and `.github/workflows/docs-check.yml`
among six files. The scope step resolved `2 changed path(s) can affect this
gate` (the four `.md` paths in that diff are inert) and ran everything:
`Formatted 355 files (0 changed)`, `No issues found!`, `All tests passed!`.
The `push` event on `main` after the squash-merge
(run 36138938309, `push-to-main-quality-gate-run.log`) took the same branch:
`- event: push`, `- expensive steps run: true`.

### Criterion 3

Run 36139123873, the docs-only pull request: `createdAt 13:08:50`,
`updatedAt 13:09:01` - **11 seconds** wall, 7 seconds of job time. The steps
that executed were `Set up job`, `Checkout code`, `Decide the gate scope`,
`Post Checkout code`, `Complete job`. **Setup Flutter**, **Install
dependencies**, **Verify formatting**, **Analyze code** and **Run tests** do not
appear in the log at all. No Flutter toolchain was downloaded or restored from
cache.

For contrast, the same gate on a code change takes about three minutes
(run 36138549535: 13:03:12 to 13:06:13).

### Criterion 4

Not applicable as written, and the criterion says so itself: "If protection is
not yet applied, state that and stop at criterion 3."

```
$ gh api repos/koniz-dev/flutter-starter/branches/main/protection
{"message":"Branch not protected", ... "status":"404"}
$ gh api repos/koniz-dev/flutter-starter/rulesets
[]
```

Protection is still absent, because applying it is a repository *settings*
write that a session's permission layer refuses - that is criterion 5 of
koniz-dev/flutter-starter#58, parked at `status:needs-uat` for a human.

What this issue changed is that the request is now safe to grant. `main`'s head
commit reports these check runs:

```
$ gh api repos/koniz-dev/flutter-starter/commits/main/check-runs --jq '[.check_runs[].name]|sort'
["Quality gate","Strip both-samples-removed + analyze + test",
 "Strip feature-flags-removed + analyze + test","Strip tasks-removed + analyze + test"]
```

and criterion 1 above shows `Quality gate` also reporting on a docs-only pull
request. Listing it under `required_status_checks.contexts` no longer strands
evidence pull requests on "Expected - waiting for status to be reported".

### Criterion 5

`./scripts/dev/audit_template.sh` and `./scripts/test/run_acceptance.sh 117
--no-goldens` both exited 0 locally: `format.log` (`dart format` reports no
changes), `analyze.log` (`No issues found!`), `tests.log` (`All tests passed!`,
2650 tests, 8 skipped). `--no-goldens` because the diff touches nothing under
`lib/`, so no golden could have moved.

`dart run tool/check_docs.dart` also passes: 552 relative links checked, 0
broken; 70 files scanned, 0 emoji lines.

## Files

| File | What it is |
|---|---|
| [`criterion-1-docs-only-pr-checks.log`](criterion-1-docs-only-pr-checks.log) | `gh pr diff --name-only` and `gh pr checks` for the docs-only pull request #156 |
| [`criterion-1-3-docs-only-quality-gate-run.log`](criterion-1-3-docs-only-quality-gate-run.log) | Full Quality gate run log for #156 (run 36139123873) - shows `expensive steps run: false` and the absence of every Flutter step |
| [`criterion-2-broken-code-pr-checks.log`](criterion-2-broken-code-pr-checks.log) | `gh pr checks` for #155, the deliberately misformatted pull request; Quality gate `fail`, Strip jobs `pass` |
| [`criterion-2-broken-code-quality-gate-failure.log`](criterion-2-broken-code-quality-gate-failure.log) | `gh run view --log-failed` - the exact failing step and its exit code |
| [`criterion-2-broken-code-quality-gate-run.log`](criterion-2-broken-code-quality-gate-run.log) | Trimmed full run log for #155 |
| [`criterion-2-code-pr-154-checks.log`](criterion-2-code-pr-154-checks.log) | `gh pr checks` and merge state for the shipping pull request #154 |
| [`criterion-2-code-pr-154-quality-gate-run.log`](criterion-2-code-pr-154-quality-gate-run.log) | Trimmed run log for #154 - scope step plus every step boundary and result line |
| [`push-to-main-quality-gate-run.log`](push-to-main-quality-gate-run.log) | Same, for the `push` event on `main` after the merge |
| [`criterion-3-run-durations.log`](criterion-3-run-durations.log) | `createdAt`/`updatedAt`/`conclusion` for all four runs |
| [`criterion-4-branch-protection.log`](criterion-4-branch-protection.log) | Branch protection and ruleset state, plus the check runs reporting on `main` |
| [`docs-only-probe.md`](docs-only-probe.md) | The file that made #156 a docs-only pull request |
| [`format.log`](format.log), [`analyze.log`](analyze.log), [`tests.log`](tests.log) | Local `run_acceptance.sh 117 --no-goldens` output |

The two large run logs are trimmed: they keep the whole `Decide the gate scope`
step, the `##[group]Run` line that opens every other step, and the result lines
of format, analyze and test, and drop roughly 2600 per-test progress lines. Each
trimmed file names the untouched run URL at the top.

## Not verified here

- **Branch protection actually enforcing anything.** Nothing is protected, so
  nothing was enforced. Criterion 4 shows the gate is now *eligible*; it does
  not show it *required*.
- **Fork pull requests.** Every run above is same-repository. A fork pull
  request gets a restricted `GITHUB_TOKEN`, but the scope step only reads the
  local git history, so no behaviour difference is expected - it was not
  exercised.
- **A docs-only change that also touches `docs/**/*.dart`.** The filter treats
  it as relevant (unit-checked locally against six path sets before the change
  was pushed), but no pull request drove that path through CI.
