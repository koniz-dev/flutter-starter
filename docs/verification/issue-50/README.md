# Issue 50 - strip variants produce a tree that does not compile

Verification evidence for koniz-dev/flutter-starter#50, against the merged fix
on `main` (PR #93, commit `0ea4550`).

## Provenance

The fix merged with CI green, but the session that wrote it was terminated by
an API rate limit before it ran acceptance verification. This evidence was
produced afterwards by the orchestrating session.

Criteria 1-4 and 6 were driven in **fresh `git clone`s of `origin/main`**, not
in a worktree, because the criteria say "in a clean clone" and a worktree
carries build artefacts a clone does not.

## Criterion to artifact

| # | Criterion | Verdict | Artifact |
|---|---|---|---|
| 1 | `--apply --remove-tasks` in a clean clone, then `pub get && analyze`, exits 0 with `No issues found!` | PASS | `strip-variants-analyze-test.log` - *--remove-tasks*: `No issues found! (ran in 6.0s)` |
| 2 | The same for `--remove-feature-flags` | PASS | `strip-variants-analyze-test.log` - *--remove-feature-flags*: `No issues found! (ran in 6.0s)` |
| 3 | The same still holds for the bare `--apply` (no regression) | PASS | `strip-variants-analyze-test.log` - *bare --apply*: `No issues found! (ran in 5.9s)` |
| 4 | `flutter test` passes in all three stripped trees | PASS | `strip-variants-analyze-test.log` - `+1923` (removeBoth), `+2099` (tasks removed), `+2229` (feature-flags removed), all `All tests passed!` |
| 5 | `strip-smoke.yml` exercises all three variants; a deliberately broken golden must make the job red - demonstrate it | PASS | `.github/workflows/strip-smoke.yml:38-45` - a `matrix.include` over `both-samples-removed` / `tasks-removed` / `feature-flags-removed`. Demonstration in `broken-golden-demo.log` |
| 6 | Both flags together behave as `removeBoth`, or are rejected **before** anything is deleted | PASS | Driven in a clean clone: `--apply --remove-tasks --remove-feature-flags` exits 0 with `Strip complete`, and the resulting tree analyzes clean and passes 1923 tests - i.e. it behaves as `removeBoth` |
| 7 | Either `tool/golden/**` is no longer excluded from analyze, or the issue explains why the criterion-5 matrix suffices | PASS | The exclusion stays, with the rationale written into `analysis_options.yaml:17-23`. `broken-golden-demo.log` is the empirical backing |
| 8 | `./scripts/dev/audit_template.sh` exits 0 | PASS | `audit_template.log` - `AUDIT_EXIT=0`, `+2407 ~5: All tests passed!` |

## Criterion 5, the demonstration

The matrix alone only proves the three variants pass today. The criterion asks
for proof that the job would *catch* a regression, so it was provoked:

1. Fresh clone of `origin/main`.
2. Appended invalid Dart to
   `tool/golden/stripped/lib/core/routing/routes_registry.dart`.
3. Ran the bare `--apply` strip, which copies that golden into place.
4. `flutter analyze` exited **1** with 5 errors, beginning
   `Invalid reference to 'this' expression • lib/core/routing/routes_registry.dart:13:29`.

A red analyze in that step is a red matrix job, so the guard is real.

## Criterion 7, why the exclusion is sound

`analysis_options.yaml` still excludes `tool/golden/**`, and the comment there
explains why: analysing those files *in place* would measure them against the
unstripped sources they exist to replace, which is not a meaningful question.
The demonstration above closes the loop - a broken golden is still caught, at
the only point where its correctness is meaningful, namely after it has been
copied into a stripped tree.

## No PNGs in this directory

This issue is entirely about whether generated trees compile and their tests
pass. Nothing here is visual, so `run_acceptance.sh`'s golden copying would add
nothing but noise; the evidence is the analyze and test output from the three
stripped trees.
