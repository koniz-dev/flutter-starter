# Issue #39 - acceptance evidence

`fix(tooling): coverage.yml prints per-layer FILE COUNTS beside real percentages,
and pipes prose into GITHUB_OUTPUT`

Change merged as PR #42 (`4f5bc36` on `main`). This directory is the evidence for
the acceptance criteria, collected after GitHub Actions resumed assigning runners.

Criterion 5 was the only outstanding item; it needed a runner and could not be
checked while Actions was queueing every job indefinitely (see the `status:blocked`
comment on the issue).

## Criteria

| # | Criterion | Artifact | Result |
|---|---|---|---|
| 1 | `Calculate coverage metrics` no longer prints per-layer file counts under a "Coverage Metrics" heading | [`criteria-1-2-4-5-coverage-run-34739181878.log`](criteria-1-2-4-5-coverage-run-34739181878.log), step `Calculate coverage metrics` | PASS |
| 2 | Anything still emitting a file count says so unambiguously | same file, same step | PASS |
| 3 | `calculate_layer_coverage.sh` separates machine-readable from human output | [`criteria-3-4-github-output-is-clean.txt`](criteria-3-4-github-output-is-clean.txt) | PASS |
| 4 | `$GITHUB_OUTPUT` contains no keys with spaces; show the parsed output | [`criteria-3-4-github-output-is-clean.txt`](criteria-3-4-github-output-is-clean.txt) and the `Enforce coverage thresholds` step in the run log | PASS |
| 5 | `Enforce coverage thresholds` still gates on the same five numbers and passes on `main`; record the run id | [`criteria-1-2-4-5-coverage-run-34739181878.log`](criteria-1-2-4-5-coverage-run-34739181878.log) | PASS - run `34739181878` |
| 6 | `./scripts/dev/audit_template.sh` exits 0 | [`criterion-6-audit_template.log`](criterion-6-audit_template.log) | PASS - exit 0, 2232 tests |

## Criterion 1 and 2 - the metrics step

The old block printed `Domain files: 15` directly under a `📊 Coverage Metrics:`
heading, beside a real percentage. It now reads:

```
📊 Overall line coverage: 89.9%

Source files measured per layer (counts, not coverage):
  domain: 15   data: 12   presentation: 11   core: 70
Per-layer coverage percentages are reported by the
'Calculate coverage by layer (architecture gates)' step above.
```

The counts survive as context, but the label says "counts, not coverage" and
points at the step that does report percentages. There is no longer a number that
can be misread as a per-layer percentage - which is what caused the bogus #25.

## Criterion 3 and 4 - clean step output

`--github-output` emits exactly eight lines, every one a `key=value`, no key
containing a space:

```
domain=100.0          domain_display=100.0%
data=96.2             data_display=96.2%
presentation=93.5     presentation_display=93.5%
core=85.2             core_display=85.2%
```

Human-readable output is only produced in the non-flag mode, which the workflow
sends to the log rather than to `$GITHUB_OUTPUT`.

The run log corroborates this from the other end: the `Enforce coverage
thresholds` step interpolates `steps.layer_coverage.outputs.*` and its rendered
`Run` block reads `DOMAIN_COV=100.0`, `DATA_COV=96.0`, `PRESENTATION_COV=95.4`,
`CORE_COV=85.1`. Real values in real keys means the outputs parsed cleanly; junk
keys like `Summary of coverage by layer=` are gone.

Local percentages differ from CI by a few tenths (96.2 vs 96.0 for data) because
the host VM and the CI runner cover marginally different lines. Not material to
any criterion - what is being checked here is the shape of the output, not the
number.

## Criterion 5 - the gate still passes on main

Run [`34739181878`](https://github.com/koniz-dev/flutter-starter/actions/runs/34739181878),
`workflow_dispatch` on `main`, concluded **success**:

```
✅ Total Coverage: 89.9% >= 80%
✅ Domain Layer: 100.0% >= 100%
✅ Data Layer: 96.0% >= 90%
✅ Presentation Layer: 95.4% >= 80%
✅ Core Layer: 85.1% >= 80%
```

Same five thresholds, same five numbers, still enforced.

## Scope note

`coverage.yml` is `workflow_dispatch` plus a weekly schedule, not a per-PR gate.
That is pre-existing and out of scope here; this issue was about the two
misleading outputs, both of which are fixed.
