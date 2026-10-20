# Issue 259 - acceptance evidence

Verification of `8b80f2d` ("chore(strip): drop this repository's process
machinery in every strip variant", PR #258). The change was already merged when
this evidence was produced; this directory is the verification phase only.

All runs are on `main` at `8b80f2d`, macOS (Darwin 24.6.0).

Note: this directory is itself process-only. Every strip variant deletes
`docs/verification/`, so the evidence below does not ship to an adopter - which
is the point of the change it verifies.

## Method

The three stripped trees were produced from pristine exports of `8b80f2d`:

```
git archive 8b80f2d | tar -x -C <scratch>/base     # 1672 files, tracked only
cp -R base v-both ; cp -R base v-tasks ; cp -R base v-flags
# in each: flutter pub get, then
dart run tool/strip_sample_features.dart --apply
dart run tool/strip_sample_features.dart --apply --remove-tasks
dart run tool/strip_sample_features.dart --apply --remove-feature-flags
```

`git archive` rather than `git clone` because `.git` here is 474 MB and the
stripper never reads it. One consequence is recorded honestly under criterion 4
below: an export has no `.git`, so `test/tooling/epic_coverage_test.dart` cannot
run there.

## Measurements (taken in this session, not quoted)

Tracked files and apparent byte size, excluding `.dart_tool/` and `build/`.
"pub-get churn" is the 21 generated files (`ios/Flutter/ephemeral/**`,
`GeneratedPluginRegistrant.*`, `local.properties`, ...) that `flutter pub get`
writes into any tree; they are subtracted to keep the comparison honest.

| tree | files (tracked-equivalent) | bytes | `du -sh` |
|---|---|---|---|
| unstripped `8b80f2d` | 1672 | 33.3 MiB | 37M |
| `--apply` | 600 | 3.6 MiB | 17M |
| `--apply --remove-tasks` | 624 | 3.8 MiB | 17M |
| `--apply --remove-feature-flags` | 635 | 4.0 MiB | 17M |

`docs/verification/` alone was 31 MB of the 37 MB before the strip.

## Criteria

| # | Criterion | Verdict | Artifact |
|---|---|---|---|
| 1 | All seven process-only paths absent, in all three variants | PASS | [both-assert.log](both-assert.log), [tasks-assert.log](tasks-assert.log), [flags-assert.log](flags-assert.log); strip transcripts [both-strip.log](both-strip.log), [tasks-strip.log](tasks-strip.log), [flags-strip.log](flags-strip.log) |
| 2 | Adopter-facing guards survive | PASS | same three `*-assert.log` (presence), [c2-guards-run.log](c2-guards-run.log) (they still execute) |
| 3 | All three trees pass `pub get`, `analyze`, `test`, and `check_docs` with zero broken links | PASS | [both-gates.log](both-gates.log), [tasks-gates.log](tasks-gates.log), [flags-gates.log](flags-gates.log) |
| 4 | The `strip-smoke.yml` assertion fails on an unstripped tree | PASS | [c4-counterfactual.log](c4-counterfactual.log), [c4-green-but-rejected.log](c4-green-but-rejected.log) |
| 5 | Unbalanced markers are a hard error before anything is deleted | PASS | [c5-counterfactual.log](c5-counterfactual.log) |
| 6 | Nothing deleted from this repository | PASS | `git diff 8b80f2d^..8b80f2d --diff-filter=D --name-only` is empty (below) |
| 7 | `CLAUDE.md` carries the scope test and is itself marked process-only | PASS | [c7-scope-test.log](c7-scope-test.log) |
| 8 | `./scripts/dev/audit_template.sh` exits 0 | PASS | [audit-main.log](audit-main.log) |

Every criterion was driven here. Nothing is routed to `status:needs-uat`.
No criterion rests on a golden image - this change renders nothing, the
acceptance run was not needed, and no PNG is cited anywhere above.

### Criterion 1 detail

Asserted absent in each of the three trees: `docs/verification`,
`tool/check_epic_coverage.dart`, `scripts/dev/check_issue_refs.sh`,
`.github/workflows/issue-refs.yml`, `.claude/agents`,
`scripts/bootstrap-issue-labels.sh`, `docs/issue-workflow.md`, and
`test/tooling/epic_coverage_test.dart`. Plus: no whole-line
`<!-- strip:process-only -->` marker survives in any kept markdown file.

`.claude/` held nothing but `agents/` (four role files), so the stripper's
prune of the now-empty `.claude/` removes no collateral.

### Criterion 2 detail

Present after every variant: `tool/check_env_assets.dart`,
`tool/check_docs.dart`, `tool/doc_signatures.dart`, `tool/doc_symbols.dart`,
`.github/workflows/ci.yml`, `.github/workflows/strip-smoke.yml`,
`.githooks/{pre-push,commit-msg,pre-commit}`, `scripts/dev/setup_git_hooks.sh`,
`scripts/dev/audit_template.sh`, `scripts/test/run_acceptance.sh`.

Presence is weaker than function, so the guards were also executed on the
stripped `--apply` tree (`c2-guards-run.log`): `check_docs` exits 0 reporting
"506 relative link(s) in 66 file(s); 0 broken", "0 line(s) with emoji",
"5 documented constructor(s); 0 mismatched", "9 directive(s); 0 unresolved" -
the last two lines are `doc_signatures.dart` and `doc_symbols.dart`, which are
libraries with no `main()` and are only reachable through `check_docs.dart`.
`check_env_assets.dart` exits 0.

### Criterion 3 detail

| tree | pub get | analyze | check_docs | test |
|---|---|---|---|---|
| `--apply` | 0 | 0, "No issues found!" | 0, 506 links / 0 broken | 0, `+2284 ~8: All tests passed!` |
| `--remove-tasks` | 0 | 0, "No issues found!" | 0, 506 links / 0 broken | 0, `+2471 ~8: All tests passed!` |
| `--remove-feature-flags` | 0 | 0, "No issues found!" | 0, 506 links / 0 broken | 0, `+2614 ~8: All tests passed!` |

### Criterion 4 - counterfactual

The step under test is `strip-smoke.yml`'s "Assert process-only artifacts are
gone". It was extracted from the workflow verbatim and run unchanged:

```bash
set -euo pipefail
leftovers=0
for path in \
  .claude \
  .github/workflows/issue-refs.yml \
  docs/issue-workflow.md \
  docs/verification \
  scripts/bootstrap-issue-labels.sh \
  scripts/dev/check_issue_refs.sh \
  test/tooling/epic_coverage_test.dart \
  tool/check_epic_coverage.dart
do
  if [ -e "$path" ]; then
    echo "still present after strip: $path"
    leftovers=$((leftovers + 1))
  fi
done
marker='^[[:space:]]*<!-- strip:process-only (start|end) -->[[:space:]]*$'
if grep -rlE "$marker" --include='*.md' . ; then
  echo "a process-only marker survived the strip"
  leftovers=$((leftovers + 1))
fi
if [ "$leftovers" -ne 0 ]; then
  echo "$leftovers process-only artifact(s) survived the strip."
  exit 1
fi
echo "All process-only artifacts were removed."
```

Result (`c4-counterfactual.log`):

- unstripped tree: names all 8 paths plus the markers in `CONTRIBUTING.md`,
  `CLAUDE.md` and `tool/README.md`, reports "9 process-only artifact(s)
  survived the strip", **exit 1**;
- stripped `--apply` tree, same script: "All process-only artifacts were
  removed", **exit 0**.

The point of the step is that `analyze` and `test` would not have caught this.
`c4-green-but-rejected.log` shows both halves against the same unstripped tree,
the real repository at `8b80f2d`: `./scripts/dev/audit_template.sh` exits 0
(format, analyze "No issues found!", `+2812 ~8: All tests passed!`) while the
assertion step on that identical tree exits 1. Format, analyze and test call
the tree clean; only the assertion notices the removals did not happen.

An earlier attempt ran the same pairing inside the `git archive` export. There
`flutter test` failed with `Bad state: listing tracked files failed (exit 128):
fatal: not a git repository`, from `test/tooling/epic_coverage_test.dart` - an
artifact of the export having no `.git`, not a defect. It is recorded here
rather than quietly dropped, and it is incidentally a good illustration of why
that test is classified process-only: it cannot run outside this repository.
The pairing above was therefore re-run against the real git repository, where
`flutter test` genuinely passes.

### Criterion 5 - counterfactual

In a throwaway copy, the closing marker at `CLAUDE.md:101` was deleted, leaving
the region opened at line 32 unclosed. Then `--apply` was run
(`c5-counterfactual.log`):

```
Process-only markers are unbalanced; nothing was deleted:
  CLAUDE.md:104: start marker inside the region opened at line 32
EXIT = 2
```

Sentinels taken before and after that run are identical: `docs/verification`
still present with the same **1003** files, `tool/check_epic_coverage.dart`,
`.claude/agents` and `docs/issue-workflow.md` all still present,
`lib/features/tasks` and `lib/features/feature_flags` both still present. The
error is reported before any deletion, and it names file and line.

### Criterion 6

```
$ git diff 8b80f2d^..8b80f2d --diff-filter=D --name-only
(no output)
```

`8b80f2d` changed six files and deleted none:
`.github/workflows/strip-smoke.yml`, `CLAUDE.md`, `CONTRIBUTING.md`,
`docs/guides/onboarding/fork-and-customize.md`, `tool/README.md`,
`tool/strip_sample_features.dart` (341 insertions, 1 deletion). The assertion
step run against this repository (criterion 4) independently confirms all eight
process-only paths are still here.

### Criterion 7

`CLAUDE.md` gained "### Scope test: would an adopter notice?" carrying the test
"**would an adopter notice if this were missing?**". The heading sits at line
106, inside the marker pair at lines 105 and 137, so it is itself process-only:
after `--apply` the stripped `CLAUDE.md` contains zero occurrences of "would an
adopter notice" and zero surviving markers, going from 381 to 89 lines while
remaining a coherent file (`# CLAUDE.md`, `## Commands`,
`## Acceptance verification`, `### What this tooling cannot verify`,
`## Conventions`).

## Observations - not defects, not filed

Recorded for the record. None of these fails a criterion, and none was filed as
an issue.

1. **Empty heading seam in the stripped `CLAUDE.md`.** The body under
   `## Acceptance verification` was inside a marked region, so after the strip
   that heading is immediately followed by `### What this tooling cannot
   verify` with no prose between them. Cosmetic; `check_docs` passes.
2. **Backticked paths are not links, so `check_docs` cannot see them.**
   Criterion 3's stated test is zero broken *relative links*, and that passes.
   But three surviving prose mentions in the adopter's tree name files the
   strip deletes:
   `docs/architecture/adr/0006-contract-status-and-slice-shape.md:115` tells the
   reader to run `./scripts/bootstrap-issue-labels.sh --list-map`;
   `docs/api/core/network.md:404` cites
   `docs/verification/issue-89/visible-for-testing-probe.log`;
   `test/tooling/import_rules_test.dart:63` mentions the labels script in a
   comment. The mentions in `tool/README.md` and
   `docs/guides/onboarding/fork-and-customize.md` are deliberate - those
   passages document what the strip removes.
3. **The strip is not idempotent.** A second `--apply` on an already-stripped
   tree throws `Bad state: Task Fixtures section not found`. Pre-existing,
   unrelated to `8b80f2d`, did not obstruct this verification.

## QA

Self-QA, not a separate `qa` pass. Checked: every row above names an artifact;
no row rests on a golden or a screenshot (none exist for this change, and none
is cited); the commits carry `Refs koniz-dev/flutter-starter#259` with no
auto-closing keyword; the issue carries exactly one `status:*` label; nothing
was routed to `needs-uat`.
